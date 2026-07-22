package com.coco.server.course;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "course_elements")
public class CourseElementEntity {
    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "course_id", nullable = false)
    private CourseEntity course;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ElementCategory category;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    @Column(name = "distance_from_start_meters", nullable = false)
    private int distanceFromStartMeters;

    @Column(nullable = false, length = 100)
    private String title;

    @Column(nullable = false, length = 500)
    private String description;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false, insertable = false, updatable = false)
    private Instant updatedAt;

    protected CourseElementEntity() {
    }

    public CourseElementEntity(
            UUID id,
            CourseEntity course,
            ElementCategory category,
            double latitude,
            double longitude,
            int distanceFromStartMeters,
            String title,
            String description
    ) {
        this.id = id;
        this.course = course;
        this.category = category;
        this.latitude = latitude;
        this.longitude = longitude;
        this.distanceFromStartMeters = distanceFromStartMeters;
        this.title = title;
        this.description = description;
    }

    public CourseEntity getCourse() {
        return course;
    }

    public void applyUpdate(
            ElementCategory category,
            Double latitude,
            Double longitude,
            Integer distanceFromStartMeters,
            String title,
            String description
    ) {
        if (category != null) {
            this.category = category;
        }
        if (latitude != null) {
            this.latitude = latitude;
        }
        if (longitude != null) {
            this.longitude = longitude;
        }
        if (distanceFromStartMeters != null) {
            this.distanceFromStartMeters = distanceFromStartMeters;
        }
        if (title != null) {
            this.title = title;
        }
        if (description != null) {
            this.description = description;
        }
    }

    public UUID getId() {
        return id;
    }

    public ElementCategory getCategory() {
        return category;
    }

    public double getLatitude() {
        return latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public int getDistanceFromStartMeters() {
        return distanceFromStartMeters;
    }

    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }
}
