-- 요소 사진. 이미지 바이트는 객체 저장소에 있고 DB에는 객체 키만 둔다.
-- photo_uploaded_at은 업로드가 확정된 시점이며, 확정 전에는 두 컬럼 모두 NULL이다.

ALTER TABLE course_elements
    ADD COLUMN photo_object_key VARCHAR(255),
    ADD COLUMN photo_uploaded_at TIMESTAMPTZ;

-- 키가 있으면 확정 시각도 있어야 하고, 그 반대도 성립한다.
ALTER TABLE course_elements
    ADD CONSTRAINT course_elements_photo_pair_check CHECK (
        (photo_object_key IS NULL AND photo_uploaded_at IS NULL)
        OR (photo_object_key IS NOT NULL AND photo_uploaded_at IS NOT NULL)
    );
