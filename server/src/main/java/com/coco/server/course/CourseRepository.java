package com.coco.server.course;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CourseRepository extends JpaRepository<CourseEntity, UUID> {
    @EntityGraph(attributePaths = {"owner", "routePoints", "elements"})
    @Query("select distinct course from CourseEntity course order by course.name")
    List<CourseEntity> findAllWithDetails();

    @EntityGraph(attributePaths = {"owner", "routePoints", "elements"})
    @Query("select course from CourseEntity course where course.id = :id")
    Optional<CourseEntity> findByIdWithDetails(@Param("id") UUID id);
}
