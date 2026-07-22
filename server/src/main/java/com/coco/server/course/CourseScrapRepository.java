package com.coco.server.course;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CourseScrapRepository extends JpaRepository<CourseScrapEntity, CourseScrapId> {
    @Query("""
            select scrap.id.courseId as courseId, count(scrap) as total
            from CourseScrapEntity scrap
            where scrap.id.courseId in :courseIds
            group by scrap.id.courseId
            """)
    List<CourseCountRow> countByCourseIds(@Param("courseIds") Collection<UUID> courseIds);

    @Query("""
            select scrap.id.courseId
            from CourseScrapEntity scrap
            where scrap.id.userId = :userId and scrap.id.courseId in :courseIds
            """)
    List<UUID> findScrappedCourseIds(@Param("userId") UUID userId, @Param("courseIds") Collection<UUID> courseIds);

    @Query("""
            select scrap.id.courseId
            from CourseScrapEntity scrap
            where scrap.id.userId = :userId
            order by scrap.createdAt desc, scrap.id.courseId
            """)
    List<UUID> findCourseIdsByUserId(@Param("userId") UUID userId);

    interface CourseCountRow {
        UUID getCourseId();

        long getTotal();
    }
}
