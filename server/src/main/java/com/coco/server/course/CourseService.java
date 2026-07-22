package com.coco.server.course;

import com.coco.server.common.ResourceNotFoundException;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CourseService {
    private final CourseRepository courseRepository;
    private final CourseScrapRepository courseScrapRepository;
    private final CourseReactionRepository courseReactionRepository;

    public CourseService(
            CourseRepository courseRepository,
            CourseScrapRepository courseScrapRepository,
            CourseReactionRepository courseReactionRepository
    ) {
        this.courseRepository = courseRepository;
        this.courseScrapRepository = courseScrapRepository;
        this.courseReactionRepository = courseReactionRepository;
    }

    @Transactional(readOnly = true)
    public CourseListResponse findAll(UUID userId) {
        return toListResponse(courseRepository.findAllWithDetails(), userId);
    }

    @Transactional(readOnly = true)
    public CourseResponse findById(UUID courseId, UUID userId) {
        CourseEntity course = courseRepository.findByIdWithDetails(courseId)
                .orElseThrow(CourseService::courseNotFound);
        return toListResponse(List.of(course), userId).items().getFirst();
    }

    @Transactional(readOnly = true)
    public CourseListResponse findMyCourses(UUID userId) {
        return toListResponse(courseRepository.findAllWithDetailsByOwnerId(userId), userId);
    }

    @Transactional(readOnly = true)
    public CourseListResponse findMyScraps(UUID userId) {
        List<UUID> scrappedCourseIds = courseScrapRepository.findCourseIdsByUserId(userId);
        if (scrappedCourseIds.isEmpty()) {
            return new CourseListResponse(List.of());
        }

        Map<UUID, CourseEntity> coursesById = courseRepository.findAllWithDetailsByIds(scrappedCourseIds).stream()
                .collect(Collectors.toMap(CourseEntity::getId, Function.identity()));
        List<CourseEntity> orderedCourses = scrappedCourseIds.stream()
                .map(coursesById::get)
                .toList();
        return toListResponse(orderedCourses, userId);
    }

    @Transactional
    public void scrap(UUID userId, UUID courseId) {
        ensureCourseExists(courseId);
        CourseScrapId id = new CourseScrapId(userId, courseId);
        if (!courseScrapRepository.existsById(id)) {
            courseScrapRepository.save(new CourseScrapEntity(id));
        }
    }

    @Transactional
    public void unscrap(UUID userId, UUID courseId) {
        ensureCourseExists(courseId);
        courseScrapRepository.deleteById(new CourseScrapId(userId, courseId));
    }

    @Transactional
    public void addReaction(UUID userId, UUID courseId, ReactionType type) {
        ensureCourseExists(courseId);
        CourseReactionId id = new CourseReactionId(userId, courseId, type);
        if (!courseReactionRepository.existsById(id)) {
            courseReactionRepository.save(new CourseReactionEntity(id));
        }
    }

    @Transactional
    public void removeReaction(UUID userId, UUID courseId, ReactionType type) {
        ensureCourseExists(courseId);
        courseReactionRepository.deleteById(new CourseReactionId(userId, courseId, type));
    }

    private void ensureCourseExists(UUID courseId) {
        if (!courseRepository.existsById(courseId)) {
            throw courseNotFound();
        }
    }

    private CourseListResponse toListResponse(List<CourseEntity> courses, UUID userId) {
        if (courses.isEmpty()) {
            return new CourseListResponse(List.of());
        }

        List<UUID> courseIds = courses.stream().map(CourseEntity::getId).toList();

        Map<UUID, Integer> scrapCounts = new LinkedHashMap<>();
        for (CourseScrapRepository.CourseCountRow row : courseScrapRepository.countByCourseIds(courseIds)) {
            scrapCounts.put(row.getCourseId(), (int) row.getTotal());
        }

        Map<UUID, Map<ReactionType, Long>> reactionCounts = new LinkedHashMap<>();
        for (CourseReactionRepository.ReactionCountRow row : courseReactionRepository.countByCourseIds(courseIds)) {
            reactionCounts
                    .computeIfAbsent(row.getCourseId(), ignored -> new LinkedHashMap<>())
                    .put(row.getReactionType(), row.getTotal());
        }

        Set<UUID> scrappedCourseIds = new HashSet<>(courseScrapRepository.findScrappedCourseIds(userId, courseIds));

        Map<UUID, Set<ReactionType>> myReactions = new LinkedHashMap<>();
        for (CourseReactionRepository.UserReactionRow row : courseReactionRepository.findUserReactions(userId, courseIds)) {
            myReactions
                    .computeIfAbsent(row.getCourseId(), ignored -> EnumSet.noneOf(ReactionType.class))
                    .add(row.getReactionType());
        }

        List<CourseResponse> items = courses.stream()
                .map(course -> CourseResponse.from(
                        course,
                        scrapCounts.getOrDefault(course.getId(), 0),
                        ReactionCountsResponse.from(reactionCounts.getOrDefault(course.getId(), Map.of())),
                        scrappedCourseIds.contains(course.getId()),
                        myReactions.getOrDefault(course.getId(), Set.of())
                ))
                .toList();
        return new CourseListResponse(items);
    }

    private static ResourceNotFoundException courseNotFound() {
        return new ResourceNotFoundException("COURSE_NOT_FOUND", "코스를 찾을 수 없습니다.");
    }
}
