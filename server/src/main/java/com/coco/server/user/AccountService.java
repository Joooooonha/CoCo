package com.coco.server.user;

import com.coco.server.common.ResourceNotFoundException;
import com.coco.server.course.CourseRepository;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// Deletes an account and everything attached to it in one transaction.
@Service
public class AccountService {
    private final UserRepository userRepository;
    private final CourseRepository courseRepository;

    public AccountService(UserRepository userRepository, CourseRepository courseRepository) {
        this.userRepository = userRepository;
        this.courseRepository = courseRepository;
    }

    @Transactional
    public void deleteAccount(UUID userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("USER_NOT_FOUND", "사용자를 찾을 수 없습니다."));

        // `courses.owner_id` is ON DELETE RESTRICT, so the user's own courses must
        // go first. Deleting a course cascades to its route points, elements, and
        // to every user's scraps and reactions on it.
        courseRepository.deleteByOwnerId(userId);
        courseRepository.flush();

        // Deleting the user cascades to auth tokens, external identities, and the
        // scraps and reactions this user left on other people's courses.
        userRepository.delete(user);
    }
}
