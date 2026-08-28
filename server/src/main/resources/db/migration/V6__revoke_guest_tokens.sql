-- 소셜 로그인을 필수로 바꾸면서, 기기에만 존재하던 게스트 신원은 더 이상
-- 유효한 진입 수단이 아니다. 이미 발급된 게스트 토큰을 남겨두면 그 기기에서는
-- 계속 통과되어 "모든 계정은 소셜 제공자에서 온다"는 전제가 깨진다.
--
-- 계정과 코스는 지우지 않는다. 지금 시점의 게스트 데이터는 개발 중 만들어진
-- 것이고, 지우는 판단은 별도로 내릴 일이다. 여기서는 접근만 끊는다.

UPDATE auth_tokens
SET revoked_at = now()
WHERE revoked_at IS NULL
  AND user_id IN (SELECT id FROM users WHERE account_type = 'GUEST');
