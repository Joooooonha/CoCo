package com.coco.server.course;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "course_scraps")
public class CourseScrapEntity {
    @EmbeddedId
    private CourseScrapId id;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    protected CourseScrapEntity() {
    }

    public CourseScrapEntity(CourseScrapId id) {
        this.id = id;
    }

    public CourseScrapId getId() {
        return id;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
