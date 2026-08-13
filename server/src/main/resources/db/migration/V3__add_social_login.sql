-- 소셜 로그인 도입: 계정 유형을 GUEST/MEMBER로 재정의하고 외부 신원 테이블을 추가한다.
-- 기존 APPLE 값은 실제로 발급된 적이 없으나 안전을 위해 MEMBER로 옮긴 뒤 제약을 교체한다.

ALTER TABLE users DROP CONSTRAINT users_account_type_check;

UPDATE users SET account_type = 'MEMBER' WHERE account_type = 'APPLE';

ALTER TABLE users
    ADD CONSTRAINT users_account_type_check CHECK (account_type IN ('GUEST', 'MEMBER'));

CREATE TABLE external_identities (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(20) NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT external_identities_provider_check CHECK (provider IN ('NAVER', 'KAKAO')),
    -- 하나의 외부 신원은 한 사용자에게만 연결된다.
    CONSTRAINT external_identities_provider_user_unique UNIQUE (provider, provider_user_id),
    -- 한 사용자는 제공자별로 최대 하나의 외부 신원을 가진다.
    CONSTRAINT external_identities_user_provider_unique UNIQUE (user_id, provider)
);

CREATE INDEX external_identities_user_id_index ON external_identities(user_id);
