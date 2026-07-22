package com.coco.server.course;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

@Embeddable
public class CourseReactionId implements Serializable {
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "course_id", nullable = false)
    private UUID courseId;

    @Enumerated(EnumType.STRING)
    @Column(name = "reaction_type", nullable = false, length = 20)
    private ReactionType reactionType;

    protected CourseReactionId() {
    }

    public CourseReactionId(UUID userId, UUID courseId, ReactionType reactionType) {
        this.userId = userId;
        this.courseId = courseId;
        this.reactionType = reactionType;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getCourseId() {
        return courseId;
    }

    public ReactionType getReactionType() {
        return reactionType;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof CourseReactionId that)) {
            return false;
        }
        return Objects.equals(userId, that.userId)
                && Objects.equals(courseId, that.courseId)
                && reactionType == that.reactionType;
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, courseId, reactionType);
    }
}
