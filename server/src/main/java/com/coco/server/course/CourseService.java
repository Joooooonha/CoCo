package com.coco.server.course;

import com.coco.server.common.ResourceNotFoundException;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CourseService {
    private final CourseRepository courseRepository;

    public CourseService(CourseRepository courseRepository) {
        this.courseRepository = courseRepository;
    }

    @Transactional(readOnly = true)
    public CourseListResponse findAll() {
        return new CourseListResponse(
                courseRepository.findAllWithDetails().stream()
                        .map(CourseResponse::from)
                        .toList()
        );
    }

    @Transactional(readOnly = true)
    public CourseResponse findById(UUID courseId) {
        return courseRepository.findByIdWithDetails(courseId)
                .map(CourseResponse::from)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "COURSE_NOT_FOUND",
                        "코스를 찾을 수 없습니다."
                ));
    }
}
