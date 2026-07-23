package com.coco.server.course;

import com.coco.server.auth.AuthenticatedUser;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/courses")
public class CourseController {
    private final CourseService courseService;

    public CourseController(CourseService courseService) {
        this.courseService = courseService;
    }

    @GetMapping
    public CourseListResponse findAll(@AuthenticationPrincipal AuthenticatedUser user) {
        return courseService.findAll(user.id());
    }

    @GetMapping("/{courseId}")
    public CourseResponse findById(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable UUID courseId
    ) {
        return courseService.findById(courseId, user.id());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CourseResponse create(
            @AuthenticationPrincipal AuthenticatedUser user,
            @Valid @RequestBody CourseCreateRequest request
    ) {
        return courseService.create(user.id(), request);
    }

    @DeleteMapping("/{courseId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCourse(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable UUID courseId
    ) {
        courseService.deleteCourse(user.id(), courseId);
    }

    @PostMapping("/{courseId}/elements")
    @ResponseStatus(HttpStatus.CREATED)
    public CourseElementResponse addElement(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable UUID courseId,
            @Valid @RequestBody ElementCreateRequest request
    ) {
        return courseService.addElement(user.id(), courseId, request);
    }

    @PatchMapping("/{courseId}/elements/{elementId}")
    public CourseElementResponse updateElement(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable UUID courseId,
            @PathVariable UUID elementId,
            @Valid @RequestBody ElementUpdateRequest request
    ) {
        return courseService.updateElement(user.id(), courseId, elementId, request);
    }

    @DeleteMapping("/{courseId}/elements/{elementId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteElement(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable UUID courseId,
            @PathVariable UUID elementId
    ) {
        courseService.deleteElement(user.id(), courseId, elementId);
    }

    @PutMapping("/{courseId}/scrap")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void scrap(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable UUID courseId
    ) {
        courseService.scrap(user.id(), courseId);
    }

    @DeleteMapping("/{courseId}/scrap")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unscrap(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable UUID courseId
    ) {
        courseService.unscrap(user.id(), courseId);
    }

    @PutMapping("/{courseId}/reactions/{type}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void addReaction(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable UUID courseId,
            @PathVariable ReactionType type
    ) {
        courseService.addReaction(user.id(), courseId, type);
    }

    @DeleteMapping("/{courseId}/reactions/{type}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeReaction(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable UUID courseId,
            @PathVariable ReactionType type
    ) {
        courseService.removeReaction(user.id(), courseId, type);
    }
}
