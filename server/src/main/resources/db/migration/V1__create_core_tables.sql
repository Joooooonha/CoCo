CREATE TABLE users (
    id UUID PRIMARY KEY,
    display_name VARCHAR(80) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT users_account_type_check CHECK (account_type IN ('GUEST', 'APPLE'))
);

CREATE TABLE auth_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash CHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX auth_tokens_user_id_index ON auth_tokens(user_id);

CREATE TABLE courses (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    summary VARCHAR(255) NOT NULL,
    difficulty VARCHAR(20) NOT NULL,
    location_label VARCHAR(120) NOT NULL,
    distance_meters INTEGER NOT NULL,
    estimated_duration_seconds INTEGER NOT NULL,
    route_source VARCHAR(30) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT courses_difficulty_check CHECK (difficulty IN ('EASY', 'MODERATE', 'HARD')),
    CONSTRAINT courses_route_source_check CHECK (
        route_source IN ('PLANNED_MAPKIT', 'RECORDED_GPS', 'IMPORTED_GPX', 'PLANNED_KAKAO')
    ),
    CONSTRAINT courses_distance_check CHECK (distance_meters > 0),
    CONSTRAINT courses_duration_check CHECK (estimated_duration_seconds > 0)
);

CREATE INDEX courses_owner_id_index ON courses(owner_id);

CREATE TABLE course_route_points (
    id UUID PRIMARY KEY,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    sequence_number INTEGER NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    CONSTRAINT course_route_points_sequence_unique UNIQUE (course_id, sequence_number),
    CONSTRAINT course_route_points_sequence_check CHECK (sequence_number >= 0),
    CONSTRAINT course_route_points_latitude_check CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT course_route_points_longitude_check CHECK (longitude BETWEEN -180 AND 180)
);

CREATE INDEX course_route_points_course_id_index ON course_route_points(course_id);

CREATE TABLE course_elements (
    id UUID PRIMARY KEY,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    category VARCHAR(20) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    distance_from_start_meters INTEGER NOT NULL,
    title VARCHAR(100) NOT NULL,
    description VARCHAR(500) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT course_elements_category_check CHECK (category IN ('VIEW', 'CAUTION', 'FACILITY')),
    CONSTRAINT course_elements_distance_check CHECK (distance_from_start_meters >= 0),
    CONSTRAINT course_elements_latitude_check CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT course_elements_longitude_check CHECK (longitude BETWEEN -180 AND 180)
);

CREATE INDEX course_elements_course_id_index ON course_elements(course_id);

CREATE TABLE course_scraps (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, course_id)
);

CREATE INDEX course_scraps_course_id_index ON course_scraps(course_id);

CREATE TABLE course_reactions (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    reaction_type VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, course_id, reaction_type),
    CONSTRAINT course_reactions_type_check CHECK (reaction_type IN ('LIKE', 'HARD', 'SCENIC'))
);

CREATE INDEX course_reactions_course_id_index ON course_reactions(course_id);
