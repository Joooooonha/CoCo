package com.coco.server.course;

import com.coco.server.user.UserEntity;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Entity
@Table(name = "courses")
public class CourseEntity {
    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_id", nullable = false)
    private UserEntity owner;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, length = 255)
    private String summary;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CourseDifficulty difficulty;

    @Column(name = "location_label", nullable = false, length = 120)
    private String locationLabel;

    @Column(name = "distance_meters", nullable = false)
    private int distanceMeters;

    @Column(name = "estimated_duration_seconds", nullable = false)
    private int estimatedDurationSeconds;

    @Enumerated(EnumType.STRING)
    @Column(name = "route_source", nullable = false, length = 30)
    private RouteSource routeSource;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false, insertable = false, updatable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sequenceNumber ASC")
    private Set<RoutePointEntity> routePoints = new LinkedHashSet<>();

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("distanceFromStartMeters ASC")
    private Set<CourseElementEntity> elements = new LinkedHashSet<>();

    protected CourseEntity() {
    }

    public UUID getId() {
        return id;
    }

    public UserEntity getOwner() {
        return owner;
    }

    public String getName() {
        return name;
    }

    public String getSummary() {
        return summary;
    }

    public CourseDifficulty getDifficulty() {
        return difficulty;
    }

    public String getLocationLabel() {
        return locationLabel;
    }

    public int getDistanceMeters() {
        return distanceMeters;
    }

    public int getEstimatedDurationSeconds() {
        return estimatedDurationSeconds;
    }

    public RouteSource getRouteSource() {
        return routeSource;
    }

    public List<RoutePointEntity> getRoutePoints() {
        return routePoints.stream()
                .sorted(Comparator.comparingInt(RoutePointEntity::getSequenceNumber))
                .toList();
    }

    public List<CourseElementEntity> getElements() {
        return elements.stream()
                .sorted(Comparator.comparingInt(CourseElementEntity::getDistanceFromStartMeters))
                .toList();
    }
}
