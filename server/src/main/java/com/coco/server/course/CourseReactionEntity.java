package com.coco.server.course;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "course_reactions")
public class CourseReactionEntity {
    @EmbeddedId
    private CourseReactionId id;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    protected CourseReactionEntity() {
    }

    public CourseReactionEntity(CourseReactionId id) {
        this.id = id;
    }

    public CourseReactionId getId() {
        return id;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
