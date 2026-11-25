#!/usr/bin/env python3
"""Build the Excel workbooks and the zip a seller uploads once."""

from __future__ import annotations

import zipfile
from pathlib import Path

from openpyxl import Workbook
from openpyxl.chart import BarChart, Reference
from openpyxl.chart.label import DataLabelList
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.worksheet.page import PageMargins

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
EXCEL = DIST / "엑셀"

INK = "1C1F1C"
YELLOW = "FFF4CC"
PAPER = "F4F1EA"
WHITE = "FFFFFF"
LINE = "222222"

thin = Border(
    left=Side(style="thin", color=LINE),
    right=Side(style="thin", color=LINE),
    top=Side(style="thin", color=LINE),
    bottom=Side(style="thin", color=LINE),
)
font_name = "Malgun Gothic"
base_font = Font(name=font_name, size=10, color=INK)
header_font = Font(name=font_name, size=10, color=WHITE, bold=True)
title_font = Font(name=font_name, size=20, bold=True, color=INK)
label_font = Font(name=font_name, size=10, bold=True, color=INK)
fill_header = PatternFill("solid", fgColor=INK)
fill_input = PatternFill("solid", fgColor=YELLOW)
fill_formula = PatternFill("solid", fgColor=PAPER)
fill_label = PatternFill("solid", fgColor="F3F0E8")
center = Alignment(horizontal="center", vertical="center", wrap_text=True)
left = Alignment(horizontal="left", vertical="center", wrap_text=True)
right = Alignment(horizontal="right", vertical="center")


def style_range(ws, cells, font=None, fill=None, align=None, fmt=None, border=True):
    for cell in cells:
        cell.font = font or base_font
        if fill is not None:
            cell.fill = fill
        if align is not None:
            cell.alignment = align
        if fmt is not None:
            cell.number_format = fmt
        if border:
            cell.border = thin


def widths(ws, sizes):
    for index, size in enumerate(sizes, start=1):
        ws.column_dimensions[get_column_letter(index)].width = size


def page(ws, landscape=False):
    ws.page_setup.orientation = "landscape" if landscape else "portrait"
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    ws.page_setup.fitToPage = True
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 1
    ws.page_setup.horizontalCentered = True
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.page_margins = PageMargins(left=0.4, right=0.4, top=0.4, bottom=0.4, header=0.2, footer=0.2)
    ws.sheet_view.showGridLines = False
    ws.sheet_view.view = "pageBreakPreview"
    ws.sheet_view.view = "normal"
    ws.page_setup.scale = 100
    ws.print_options.horizontalCentered = True


def write_guide(ws, lines):
    ws.sheet_view.showGridLines = False
    widths(ws, [28, 88])
    ws["A1"] = "문서함"
    ws["A1"].font = title_font
    ws.merge_cells("A1:B1")
    ws["A2"] = "노란 칸만 입력합니다. 회색 칸은 계산입니다."
    ws["A2"].font = base_font
    ws.merge_cells("A2:B2")
    for row, (title, body) in enumerate(lines, start=4):
        ws.cell(row, 1, title).font = label_font
        ws.cell(row, 1).alignment = left
        ws.cell(row, 2, body).font = base_font
        ws.cell(row, 2).alignment = left
        ws.row_dimensions[row].height = 32
    page(ws)


def build_documents() -> Path:
    wb = Workbook()
    guide = wb.active
    guide.title = "안내"
    write_guide(
        guide,
        [
            ("파일", "견적서, 거래명세서, 영수증이 시트별로 분리되어 있습니다."),
            ("공급자", "설정 시트의 노란 칸이 세 문서의 공급자란으로 연결됩니다."),
            ("품목", "각 문서의 노란 품목 칸은 그 문서만의 내용입니다."),
            ("부가세", "별도, 포함, 면세 중 하나를 고릅니다. 포함은 품목 금액이 합계입니다."),
            ("인쇄", "파일 메뉴에서 인쇄합니다. A4 한 장에 맞춰 두었습니다."),
            ("세무", "이 양식은 거래 문서입니다. 세금계산서 발급을 대신하지 않습니다."),
        ],
    )

    setup = wb.create_sheet("설정", 1)
    setup.sheet_view.showGridLines = False
    widths(setup, [22, 42])
    setup["A1"] = "공급자"
    setup["A1"].font = title_font
    setup.merge_cells("A1:B1")
    labels = [
        (3, "상호"),
        (4, "대표자"),
        (5, "사업자등록번호"),
        (6, "주소"),
        (7, "업태"),
        (8, "종목"),
        (9, "전화"),
        (10, "이메일"),
        (11, "계좌"),
    ]
    for row, label in labels:
        setup.cell(row, 1, label)
        style_range(setup, [setup.cell(row, 1)], font=label_font, fill=fill_label, align=center)
        style_range(setup, [setup.cell(row, 2)], fill=fill_input, align=left)
        setup.row_dimensions[row].height = 22
    page(setup)

    def doc_sheet(name, extra_label, extra_default):
        ws = wb.create_sheet(name)
        ws.sheet_view.showGridLines = False
        widths(ws, [16, 18, 14, 16, 18, 22])
        ws.merge_cells("A1:F1")
        ws["A1"] = name
        ws["A1"].font = title_font
        ws["A1"].alignment = center
        ws.row_dimensions[1].height = 32

        pairs = [("A2", "문서번호", "B2"), ("D2", "작성일", "E2"), ("A3", extra_label, "B3"), ("D3", "부가세", "E3")]
        for label_cell, label, value_cell in pairs:
            ws[label_cell] = label
            style_range(ws, [ws[label_cell]], font=label_font, fill=fill_label, align=center)
        ws.merge_cells("B2:C2")
        ws.merge_cells("E2:F2")
        ws.merge_cells("B3:C3")
        ws.merge_cells("E3:F3")
        for ref in ("B2", "E2", "B3", "E3"):
            style_range(ws, [ws[ref]], fill=fill_input, align=left)
        ws["E2"].number_format = "YYYY-MM-DD"
        ws["B3"] = extra_default
        ws["E3"] = "별도"
        vat_list = DataValidation(type="list", formula1='"별도,포함,면세"', allow_blank=False)
        vat_list.add("E3")
        ws.add_data_validation(vat_list)

        ws.merge_cells("A5:C5")
        ws.merge_cells("D5:F5")
        ws["A5"] = "공급받는 자"
        ws["D5"] = "공급자"
        style_range(ws, [ws["A5"], ws["D5"]], font=header_font, fill=fill_header, align=center)

        buyer = [(6, "상호"), (7, "담당"), (8, "연락처"), (9, "이메일")]
        for row, label in buyer:
            ws.cell(row, 1, label)
            style_range(ws, [ws.cell(row, 1)], font=label_font, fill=fill_label, align=center)
            ws.merge_cells(start_row=row, start_column=2, end_row=row, end_column=3)
            style_range(ws, [ws.cell(row, 2)], fill=fill_input, align=left)
            ws.row_dimensions[row].height = 20

        seller_formulas = {
            6: '=IF(설정!B3="","",설정!B3)',
            7: '=IF(설정!B4="","",설정!B4)',
            8: '=IF(설정!B5="","",설정!B5)',
            9: '=IF(설정!B6="","",설정!B6)',
            10: '=TRIM(설정!B7&IF(AND(설정!B7<>"",설정!B8<>"")," / ","")&설정!B8)',
            11: '=IF(설정!B9="","",설정!B9)',
            12: '=IF(설정!B10="","",설정!B10)',
            13: '=IF(설정!B11="","",설정!B11)',
        }
        seller_labels = {
            6: "상호",
            7: "대표",
            8: "등록번호",
            9: "주소",
            10: "업태/종목",
            11: "전화",
            12: "이메일",
            13: "계좌",
        }
        for row, label in seller_labels.items():
            ws.cell(row, 4, label)
            style_range(ws, [ws.cell(row, 4)], font=label_font, fill=fill_label, align=center)
            ws.merge_cells(start_row=row, start_column=5, end_row=row, end_column=6)
            ws.cell(row, 5, seller_formulas[row])
            style_range(ws, [ws.cell(row, 5)], fill=fill_formula, align=left)
            ws.row_dimensions[row].height = 20

        ws.merge_cells("A15:D15")
        ws["A15"] = "합계금액"
        style_range(ws, [ws["A15"]], font=label_font, fill=fill_label, align=center)
        ws.merge_cells("E15:F15")
        ws["E15"] = "=F34"
        style_range(ws, [ws["E15"]], font=Font(name=font_name, size=14, bold=True), fill=fill_formula, align=right, fmt="#,##0")

        headers = ["품명", "규격", "수량", "단가", "금액", "비고"]
        for col, header in enumerate(headers, start=1):
            ws.cell(16, col, header)
        style_range(ws, [ws.cell(16, col) for col in range(1, 7)], font=header_font, fill=fill_header, align=center)

        for row in range(17, 32):
            ws.cell(row, 5, f'=IF(OR(C{row}="",D{row}=""),"",ROUND(C{row}*D{row},0))')
            for col in range(1, 7):
                cell = ws.cell(row, col)
                is_formula = col == 5
                style_range(
                    ws,
                    [cell],
                    fill=fill_formula if is_formula else fill_input,
                    align=right if col in (3, 4, 5) else left,
                    fmt="#,##0" if col in (4, 5) else None,
                )
            ws.row_dimensions[row].height = 18

        ws["A33"] = "공급가액"
        ws["C33"] = "세액"
        ws["E33"] = "합계"
        for ref in ("A33", "C33", "E33"):
            style_range(ws, [ws[ref]], font=label_font, fill=fill_label, align=center)
        ws["B34"] = '=IF(E3="포함",ROUND(SUM(E17:E31)/1.1,0),SUM(E17:E31))'
        ws["D34"] = '=IF(E3="면세",0,IF(E3="포함",SUM(E17:E31)-B34,ROUND(B34*0.1,0)))'
        ws["F34"] = '=IF(E3="포함",SUM(E17:E31),B34+D34)'
        for ref in ("B34", "D34", "F34"):
            style_range(ws, [ws[ref]], font=label_font, fill=fill_formula, align=right, fmt="#,##0")
        ws.merge_cells("A36:F36")
        ws["A36"] = "비고"
        style_range(ws, [ws["A36"]], font=label_font, fill=fill_label, align=left, border=True)
        ws.merge_cells("A37:F39")
        style_range(ws, [ws["A37"]], fill=fill_input, align=Alignment(horizontal="left", vertical="top", wrap_text=True))
        ws.row_dimensions[37].height = 20
        ws.print_area = "A1:F39"
        ws.page_setup.fitToHeight = 1
        ws.oddFooter.center.text = "공급가액·세액·합계는 수식입니다."
        page(ws)
        return ws

    doc_sheet("견적서", "유효기간", "")
    doc_sheet("거래명세서", "인도일", "")
    doc_sheet("영수증", "문구", "위 금액을 영수합니다.")
    wb.active = wb["견적서"]
    path = EXCEL / "1인사업_대외문서.xlsx"
    wb.save(path)
    return path


def build_ledger() -> Path:
    wb = Workbook()
    guide = wb.active
    guide.title = "안내"
    write_guide(
        guide,
        [
            ("입력", "매출과 비용 시트에서 날짜와 공급가액을 입력합니다. 수식은 300행까지 들어 있습니다."),
            ("면세", "면세 거래만 면세 칸에 Y를 적습니다. 비워 두면 공급가액의 10%를 세액으로 계산합니다."),
            ("월별", "월별요약의 연도를 바꾸면 1월부터 12월이 다시 집계됩니다."),
            ("차액", "차액은 매출 합계에서 비용 합계를 뺀 값입니다."),
            ("세무", "세액 차감은 가계산입니다. 부가세 신고는 홈택스 또는 세무사 기준으로 합니다."),
        ],
    )

    def entry_sheet(title, party_label, last_label):
        ws = wb.create_sheet(title)
        headers = ["날짜", party_label, "적요", "공급가액", "면세(Y)", "세액", "합계", last_label]
        widths(ws, [14, 22, 28, 14, 12, 12, 14, 16])
        for col, header in enumerate(headers, start=1):
            ws.cell(1, col, header)
        style_range(ws, [ws.cell(1, col) for col in range(1, 9)], font=header_font, fill=fill_header, align=center)
        ws.auto_filter.ref = "A1:H301"
        ws.freeze_panes = "A2"
        ws.auto_filter.ref = "A1:H1"
        mark = DataValidation(type="list", formula1='"Y,N"', allow_blank=True)
        mark.add("E2:E301")
        ws.add_data_validation(mark)
        for row in range(2, 302):
            ws.cell(row, 6, f'=IF(D{row}="","",IF(E{row}="Y",0,ROUND(D{row}*0.1,0)))')
            ws.cell(row, 7, f'=IF(D{row}="","",D{row}+F{row})')
            for col in range(1, 9):
                cell = ws.cell(row, col)
                formula = col in (6, 7)
                style_range(
                    ws,
                    [cell],
                    fill=fill_formula if formula else fill_input,
                    align=right if col in (4, 6, 7) else left,
                    fmt="YYYY-MM-DD" if col == 1 else ("#,##0" if col in (4, 6, 7) else None),
                    border=False,
                )
        ws.auto_filter.ref = "A1:H301"
        ws.freeze_panes = "A2"
        ws.page_setup.orientation = "landscape"
        ws.page_setup.paperSize = ws.PAPERSIZE_A4
        ws.page_setup.fitToPage = True
        ws.page_setup.fitToWidth = 1
        ws.page_setup.fitToHeight = 0
        ws.sheet_properties.pageSetUpPr.fitToPage = True
        ws.page_margins = PageMargins(left=0.4, right=0.4, top=0.5, bottom=0.4)
        ws.print_title_rows = "1:1"
        ws.oddHeader.center.text = title
        return ws

    entry_sheet("매출", "거래처", "입금(Y)")
    entry_sheet("비용", "지급처", "결제수단")

    summary = wb.create_sheet("월별요약", 1)
    summary.sheet_view.showGridLines = False
    widths(summary, [10, 14, 14, 14, 14, 14, 14, 14, 16])
    summary["A1"] = "연도"
    style_range(summary, [summary["A1"]], font=label_font, fill=fill_label, align=center)
    summary["B1"] = 2026
    style_range(summary, [summary["B1"]], fill=fill_input, align=center, fmt="0")
    headers = ["월", "매출공급", "매출세액", "매출합계", "비용공급", "비용세액", "비용합계", "차액", "세액차감"]
    for col, header in enumerate(headers, start=1):
        summary.cell(3, col, header)
    style_range(summary, [summary.cell(3, col) for col in range(1, 10)], font=header_font, fill=fill_header, align=center)
    for month in range(1, 13):
        row = 3 + month
        summary.cell(row, 1, month)
        summary.cell(row, 2, f'=SUMIFS(매출!D:D,매출!A:A,">="&DATE($B$1,A{row},1),매출!A:A,"<"&DATE($B$1,A{row}+1,1))')
        summary.cell(row, 3, f'=SUMIFS(매출!F:F,매출!A:A,">="&DATE($B$1,A{row},1),매출!A:A,"<"&DATE($B$1,A{row}+1,1))')
        summary.cell(row, 4, f"=B{row}+C{row}")
        summary.cell(row, 5, f'=SUMIFS(비용!D:D,비용!A:A,">="&DATE($B$1,A{row},1),비용!A:A,"<"&DATE($B$1,A{row}+1,1))')
        summary.cell(row, 6, f'=SUMIFS(비용!F:F,비용!A:A,">="&DATE($B$1,A{row},1),비용!A:A,"<"&DATE($B$1,A{row}+1,1))')
        summary.cell(row, 7, f"=E{row}+F{row}")
        summary.cell(row, 8, f"=D{row}-G{row}")
        summary.cell(row, 9, f"=C{row}-F{row}")
        style_range(summary, [summary.cell(row, 1)], fill=fill_label, align=center)
        for col in range(2, 10):
            style_range(summary, [summary.cell(row, col)], fill=fill_formula, align=right, fmt="#,##0")
    summary["A17"] = "합계"
    style_range(summary, [summary["A17"]], font=label_font, fill=fill_label, align=center)
    for col in range(2, 10):
        letter = get_column_letter(col)
        summary.cell(17, col, f"=SUM({letter}4:{letter}15)")
        style_range(summary, [summary.cell(17, col)], font=label_font, fill=fill_formula, align=right, fmt="#,##0")
    summary["A19"] = "세액차감은 매출세액에서 비용세액을 뺀 가계산입니다. 신고 금액으로 쓰지 않습니다."
    summary["A19"].font = base_font
    summary.merge_cells("A19:I19")

    chart = BarChart()
    chart.type = "col"
    chart.title = "월별 차액"
    chart.y_axis.title = "원"
    chart.x_axis.title = "월"
    data = Reference(summary, min_col=8, min_row=3, max_row=15)
    cats = Reference(summary, min_col=1, min_row=4, max_row=15)
    chart.add_data(data, titles_from_data=True)
    chart.set_categories(cats)
    chart.shape = 4
    chart.legend = None
    chart.y_axis.numFmt = "#,##0"
    chart.dataLabels = DataLabelList()
    chart.dataLabels.showVal = False
    chart.width = 18
    chart.height = 7
    summary.add_chart(chart, "A21")
    summary.print_area = "A1:I36"
    page(summary, landscape=True)

    wb.active = summary
    path = EXCEL / "1인사업_월간장부.xlsx"
    wb.save(path)
    return path


def build_quote() -> Path:
    wb = Workbook()
    guide = wb.active
    guide.title = "안내"
    write_guide(
        guide,
        [
            ("순서", "작업 이름과 시간을 적고, 시간당 단가·수정 여유·마진·수수료를 입력합니다."),
            ("수수료", "고객 결제액에서 플랫폼이 가져가는 비율입니다. 직접 거래면 0입니다."),
            ("제안가", "인건비에 수정 여유와 마진을 더한 뒤, 수수료를 빼고도 그 금액이 남도록 올립니다."),
            ("견적서", "제안가를 대외문서 파일의 견적서 품목에 그대로 옮겨 적으면 됩니다."),
        ],
    )
    ws = wb.create_sheet("계산", 0)
    ws.sheet_view.showGridLines = False
    widths(ws, [28, 18, 18, 36])
    ws["A1"] = "프리랜서 견적 계산"
    ws["A1"].font = title_font
    ws.merge_cells("A1:C1")
    fields = [
        (3, "시간당 단가", 0, "#,##0"),
        (4, "수정 여유 %", 10, "0"),
        (5, "목표 마진 %", 20, "0"),
        (6, "플랫폼 수수료 %", 0, "0"),
    ]
    for row, label, value, fmt in fields:
        ws.cell(row, 1, label)
        style_range(ws, [ws.cell(row, 1)], font=label_font, fill=fill_label, align=left)
        ws.cell(row, 2, value)
        style_range(ws, [ws.cell(row, 2)], fill=fill_input, align=right, fmt=fmt)
    for col, header in enumerate(["작업", "시간"], start=1):
        ws.cell(8, col, header)
    style_range(ws, [ws["A8"], ws["B8"]], font=header_font, fill=fill_header, align=center)
    for row in range(9, 29):
        style_range(ws, [ws.cell(row, 1)], fill=fill_input, align=left)
        style_range(ws, [ws.cell(row, 2)], fill=fill_input, align=right, fmt="0.0")
    results = [
        (30, "작업 시간", "=SUM(B9:B28)", "0.0"),
        (31, "인건비", "=ROUND(B30*B3,0)", "#,##0"),
        (32, "수정 여유 반영", "=ROUND(B31*(1+B4/100),0)", "#,##0"),
        (33, "마진 반영", "=ROUND(B32*(1+B5/100),0)", "#,##0"),
        (34, "제안 견적", '=IF(B6>=100,"수수료는 100 미만",ROUND(B33/(1-B6/100),0))', "#,##0"),
    ]
    for row, label, formula, fmt in results:
        ws.cell(row, 1, label)
        style_range(ws, [ws.cell(row, 1)], font=label_font, fill=fill_label, align=left)
        ws.cell(row, 2, formula)
        font = Font(name=font_name, size=16, bold=True) if row == 34 else label_font
        style_range(ws, [ws.cell(row, 2)], font=font, fill=fill_formula, align=right, fmt=fmt)
    ws["D3"] = "노란 칸만 바꿉니다."
    ws["D3"].font = base_font
    ws["D34"] = "제안 견적은 고객에게 제시할 금액입니다."
    ws["D34"].font = base_font
    page(ws)
    wb.active = ws
    path = EXCEL / "프리랜서_견적계산.xlsx"
    wb.save(path)
    return path


def build_zip() -> Path:
    usage = (ROOT / "사용설명.txt").read_text(encoding="utf-8")
    target = DIST / "문서함.zip"
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("문서함/사용설명.txt", usage)
        for relative in ("index.html", "css/app.css", "js/calc.js", "js/app.js"):
            archive.write(ROOT / relative, f"문서함/{relative}")
        for path in sorted(EXCEL.glob("*.xlsx")):
            archive.write(path, f"문서함/엑셀/{path.name}")
    return target


def main() -> None:
    EXCEL.mkdir(parents=True, exist_ok=True)
    documents = build_documents()
    ledger = build_ledger()
    quote = build_quote()
    bundle = build_zip()
    from openpyxl import load_workbook

    check = load_workbook(documents)
    assert check["견적서"]["E17"].value.startswith("=IF")
    assert "ROUND(SUM(E17:E31)/1.1,0)" in check["견적서"]["B34"].value
    assert check["영수증"]["B3"].value == "위 금액을 영수합니다."
    book = load_workbook(ledger)
    assert "SUMIFS" in book["월별요약"]["B4"].value
    assert book["매출"]["F2"].value.startswith("=IF")
    assert book["월별요약"]["H17"].value == "=SUM(H4:H15)"
    priced = load_workbook(quote)
    assert "1-B6/100" in priced["계산"]["B34"].value
    with zipfile.ZipFile(bundle) as archive:
        names = set(archive.namelist())
    assert "문서함/index.html" in names
    assert "문서함/엑셀/1인사업_월간장부.xlsx" in names
    print(documents)
    print(ledger)
    print(quote)
    print(bundle)


if __name__ == "__main__":
    main()
