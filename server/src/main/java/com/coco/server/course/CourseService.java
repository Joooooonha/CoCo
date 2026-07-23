package com.coco.server.course;

import com.coco.server.common.BadRequestException;
import com.coco.server.common.ConflictException;
import com.coco.server.common.ForbiddenOperationException;
import com.coco.server.common.ResourceNotFoundException;
import com.coco.server.user.UserRepository;
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
    private static final String DEFAULT_LOCATION_LABEL = "서울";
    private static final Set<RouteSource> SUPPORTED_ROUTE_SOURCES =
            Set.of(RouteSource.PLANNED_MAPKIT, RouteSource.IMPORTED_GPX);

    private final CourseRepository courseRepository;
    private final CourseScrapRepository courseScrapRepository;
    private final CourseReactionRepository courseReactionRepository;
    private final CourseElementRepository courseElementRepository;
    private final UserRepository userRepository;

    public CourseService(
            CourseRepository courseRepository,
            CourseScrapRepository courseScrapRepository,
            CourseReactionRepository courseReactionRepository,
            CourseElementRepository courseElementRepository,
            UserRepository userRepository
    ) {
        this.courseRepository = courseRepository;
        this.courseScrapRepository = courseScrapRepository;
        this.courseReactionRepository = courseReactionRepository;
        this.courseElementRepository = courseElementRepository;
        this.userRepository = userRepository;
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

    @Transactional
    public CourseResponse create(UUID userId, CourseCreateRequest request) {
        if (!SUPPORTED_ROUTE_SOURCES.contains(request.routeSource())) {
            throw new BadRequestException("ROUTE_SOURCE_UNSUPPORTED", "지원하지 않는 경로 생성 방식입니다.");
        }
        validateRouteSequences(request.routePoints());

        var owner = userRepository.getReferenceById(userId);
        String locationLabel = request.locationLabel() == null || request.locationLabel().isBlank()
                ? DEFAULT_LOCATION_LABEL
                : request.locationLabel().strip();

        CourseEntity course = new CourseEntity(
                UUID.randomUUID(),
                owner,
                request.name().strip(),
                request.summary().strip(),
                request.difficulty(),
                locationLabel,
                request.distanceMeters(),
                request.estimatedDurationSeconds(),
                request.routeSource()
        );
        for (CourseCreateRequest.RoutePointCreateRequest point : request.routePoints()) {
            course.addRoutePoint(new RoutePointEntity(
                    UUID.randomUUID(),
                    course,
                    point.sequence(),
                    point.latitude(),
                    point.longitude()
            ));
        }
        for (ElementCreateRequest element : request.elements()) {
            course.addElement(toElementEntity(course, element));
        }

        courseRepository.saveAndFlush(course);
        return findById(course.getId(), userId);
    }

    @Transactional
    public void deleteCourse(UUID userId, UUID courseId) {
        CourseEntity course = courseRepository.findByIdWithDetails(courseId)
                .orElseThrow(CourseService::courseNotFound);
        if (!course.getOwner().getId().equals(userId)) {
            throw new ForbiddenOperationException("COURSE_OWNER_ONLY", "코스 작성자만 삭제할 수 있습니다.");
        }
        courseRepository.delete(course);
    }

    @Transactional
    public CourseElementResponse addElement(UUID userId, UUID courseId, ElementCreateRequest request) {
        CourseEntity course = courseRepository.findByIdWithDetails(courseId)
                .orElseThrow(CourseService::courseNotFound);
        ensureOwner(course, userId);

        CourseElementEntity element = toElementEntity(course, request);
        courseElementRepository.saveAndFlush(element);
        return CourseElementResponse.from(courseId, element);
    }

    @Transactional
    public CourseElementResponse updateElement(
            UUID userId,
            UUID courseId,
            UUID elementId,
            ElementUpdateRequest request
    ) {
        CourseElementEntity element = findOwnedElement(userId, courseId, elementId);
        element.applyUpdate(
                request.category(),
                request.latitude(),
                request.longitude(),
                request.distanceFromStartMeters(),
                request.title() == null ? null : request.title().strip(),
                request.description() == null ? null : request.description().strip()
        );
        return CourseElementResponse.from(courseId, element);
    }

    @Transactional
    public void deleteElement(UUID userId, UUID courseId, UUID elementId) {
        CourseElementEntity element = findOwnedElement(userId, courseId, elementId);
        if (courseElementRepository.countByCourseId(courseId) <= 1) {
            throw new ConflictException("ELEMENT_MINIMUM_REQUIRED", "코스에는 요소가 1개 이상 필요합니다.");
        }
        courseElementRepository.delete(element);
    }

    private CourseElementEntity findOwnedElement(UUID userId, UUID courseId, UUID elementId) {
        if (!courseRepository.existsById(courseId)) {
            throw courseNotFound();
        }
        CourseElementEntity element = courseElementRepository.findByIdAndCourseId(elementId, courseId)
                .orElseThrow(() -> new ResourceNotFoundException("ELEMENT_NOT_FOUND", "코스 요소를 찾을 수 없습니다."));
        ensureOwner(element.getCourse(), userId);
        return element;
    }

    private void ensureOwner(CourseEntity course, UUID userId) {
        if (!course.getOwner().getId().equals(userId)) {
            throw new ForbiddenOperationException("COURSE_OWNER_ONLY", "코스 작성자만 요소를 관리할 수 있습니다.");
        }
    }

    private CourseElementEntity toElementEntity(CourseEntity course, ElementCreateRequest request) {
        return new CourseElementEntity(
                UUID.randomUUID(),
                course,
                request.category(),
                request.latitude(),
                request.longitude(),
                request.distanceFromStartMeters(),
                request.title().strip(),
                request.description().strip()
        );
    }

    private void validateRouteSequences(List<CourseCreateRequest.RoutePointCreateRequest> routePoints) {
        Set<Integer> seen = new HashSet<>();
        for (CourseCreateRequest.RoutePointCreateRequest point : routePoints) {
            if (point.sequence() >= routePoints.size() || !seen.add(point.sequence())) {
                throw new BadRequestException(
                        "ROUTE_POINTS_INVALID",
                        "경로 지점 순서는 0부터 시작하는 연속된 값이어야 합니다."
                );
            }
        }
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
