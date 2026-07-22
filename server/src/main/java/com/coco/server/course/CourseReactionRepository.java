package com.coco.server.course;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CourseReactionRepository extends JpaRepository<CourseReactionEntity, CourseReactionId> {
    @Query("""
            select reaction.id.courseId as courseId, reaction.id.reactionType as reactionType, count(reaction) as total
            from CourseReactionEntity reaction
            where reaction.id.courseId in :courseIds
            group by reaction.id.courseId, reaction.id.reactionType
            """)
    List<ReactionCountRow> countByCourseIds(@Param("courseIds") Collection<UUID> courseIds);

    @Query("""
            select reaction.id.courseId as courseId, reaction.id.reactionType as reactionType
            from CourseReactionEntity reaction
            where reaction.id.userId = :userId and reaction.id.courseId in :courseIds
            """)
    List<UserReactionRow> findUserReactions(@Param("userId") UUID userId, @Param("courseIds") Collection<UUID> courseIds);

    interface ReactionCountRow {
        UUID getCourseId();

        ReactionType getReactionType();

        long getTotal();
    }

    interface UserReactionRow {
        UUID getCourseId();

        ReactionType getReactionType();
    }
}
