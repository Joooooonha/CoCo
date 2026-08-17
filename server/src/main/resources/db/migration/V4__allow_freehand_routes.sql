-- 자유 그리기 경로를 위한 route_source 값 추가.
-- 사용자가 지도 위에 직접 그린 경로는 도보 경로 계산을 거치지 않으므로
-- 계획 경로나 가져온 GPX와 구분해 저장한다.

ALTER TABLE courses DROP CONSTRAINT courses_route_source_check;

ALTER TABLE courses
    ADD CONSTRAINT courses_route_source_check CHECK (
        route_source IN (
            'PLANNED_MAPKIT',
            'RECORDED_GPS',
            'IMPORTED_GPX',
            'DRAWN_FREEHAND',
            'PLANNED_KAKAO'
        )
    );
