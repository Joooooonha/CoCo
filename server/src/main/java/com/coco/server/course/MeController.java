package com.coco.server.course;

import com.coco.server.auth.AuthenticatedUser;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/me")
public class MeController {
    private final CourseService courseService;

    public MeController(CourseService courseService) {
        this.courseService = courseService;
    }

    @GetMapping("/courses")
    public CourseListResponse findMyCourses(@AuthenticationPrincipal AuthenticatedUser user) {
        return courseService.findMyCourses(user.id());
    }

    @GetMapping("/scraps")
    public CourseListResponse findMyScraps(@AuthenticationPrincipal AuthenticatedUser user) {
        return courseService.findMyScraps(user.id());
    }
}
