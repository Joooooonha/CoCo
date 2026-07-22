package com.coco.server.course;

import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/courses")
public class CourseController {
    private final CourseService courseService;

    public CourseController(CourseService courseService) {
        this.courseService = courseService;
    }

    @GetMapping
    public CourseListResponse findAll() {
        return courseService.findAll();
    }

    @GetMapping("/{courseId}")
    public CourseResponse findById(@PathVariable UUID courseId) {
        return courseService.findById(courseId);
    }
}
