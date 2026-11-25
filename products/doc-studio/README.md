# 문서함

1인 사업자가 견적서, 거래명세서, 영수증, 작업 단가, 월간 장부를 자기 컴퓨터에서 만드는 파일 상품입니다. 설치와 서버가 없습니다.

소득 구조와 가격 계산은 [docs/INCOME_SYSTEM.md](../../docs/INCOME_SYSTEM.md)에 있습니다. 스마트스토어에 붙일 문구는 [listing/스마트스토어.md](listing/스마트스토어.md)에 있습니다.

## 쓰는 법

`index.html`을 크롬 또는 엣지로 엽니다. 구매자에게 넘기는 압축은 `dist/문서함.zip`입니다.

엑셀이 필요하면 아래를 실행합니다.

```bash
python3 products/doc-studio/scripts/build_workbooks.py
node --test products/doc-studio/test/calc.test.js
```

계산 규칙은 `js/calc.js` 한 곳에 있고, 화면과 테스트가 그 파일을 같이 씁니다. 엑셀 수식은 같은 반올림 규칙을 시트에 다시 적었습니다.

## 판매자가 고치지 않는 것

고객 상호를 넣어 달라는 요청, 업종별 맞춤 양식, 매주 기능 추가. 상품은 이 파일 그대로 두고, 등록은 한 번으로 끝냅니다.
