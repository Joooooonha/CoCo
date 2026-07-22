package com.coco.server.course;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CourseElementRepository extends JpaRepository<CourseElementEntity, UUID> {
    @Query("""
            select element
            from CourseElementEntity element
            join fetch element.course course
            join fetch course.owner
            where element.id = :elementId and course.id = :courseId
            """)
    Optional<CourseElementEntity> findByIdAndCourseId(
            @Param("elementId") UUID elementId,
            @Param("courseId") UUID courseId
    );

    long countByCourseId(UUID courseId);
}
