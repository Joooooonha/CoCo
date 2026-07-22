package com.coco.server.course;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

@Embeddable
public class CourseScrapId implements Serializable {
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "course_id", nullable = false)
    private UUID courseId;

    protected CourseScrapId() {
    }

    public CourseScrapId(UUID userId, UUID courseId) {
        this.userId = userId;
        this.courseId = courseId;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getCourseId() {
        return courseId;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof CourseScrapId that)) {
            return false;
        }
        return Objects.equals(userId, that.userId) && Objects.equals(courseId, that.courseId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, courseId);
    }
}
