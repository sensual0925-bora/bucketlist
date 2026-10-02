# 우리들의 버킷리스트

친구들과 함께 쓰는 버킷리스트 페이지입니다. 링크를 아는 사람은 누구나 보고 쓸 수 있어요.

- 사이트: https://sensual0925-bora.github.io/bucketlist/
- 데이터: Supabase 프로젝트 `bucketlist` (pxbbwatboylajmxeqnqd)
  - `bucket_items` 버킷 항목 (달성 여부·날짜·후기·인증 사진)
  - `bucket_joins` '나도 할래'
  - `bucket_comments` 댓글
  - Storage `bucket-photos` 인증 사진 (긴 변 1600px JPEG로 줄여서 올림)
- 처음 설정: `supabase/bucket.sql` 실행 (여러 번 실행해도 안전)
- 로그인은 없고, 처음 들어올 때 적은 이름을 기기에 기억합니다.
- 항목과 댓글은 진짜로 지워지지 않고 휴지통(`deleted_at`)으로 갑니다. 휴지통 탭에서 되살릴 수 있어요.
- 무료 플랜은 7일 동안 접속이 없으면 프로젝트가 일시정지됩니다. Supabase 대시보드에서 다시 켜면 돼요.
