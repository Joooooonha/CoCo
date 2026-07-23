package com.coco.server.course;

import com.coco.server.auth.AuthenticatedUser;
import com.coco.server.user.UserResponse;
import com.coco.server.user.UserService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/me")
public class MeController {
    public record UpdateMeRequest(@NotBlank @Size(max = 20) String displayName) {
    }

    private final CourseService courseService;
    private final UserService userService;

    public MeController(CourseService courseService, UserService userService) {
        this.courseService = courseService;
        this.userService = userService;
    }

    @PatchMapping
    public UserResponse updateMe(
            @AuthenticationPrincipal AuthenticatedUser user,
            @Valid @RequestBody UpdateMeRequest request
    ) {
        return userService.updateDisplayName(user.id(), request.displayName());
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
