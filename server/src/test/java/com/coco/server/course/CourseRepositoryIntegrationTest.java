package com.coco.server.course;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

@SpringBootTest
@Testcontainers
class CourseRepositoryIntegrationTest {
    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

    @Autowired
    private CourseRepository courseRepository;

    @Test
    void migrationsLoadTwoCoursesWithRoutesAndElements() {
        List<CourseEntity> courses = courseRepository.findAllWithDetails();

        assertThat(courses).hasSize(2);
        assertThat(courses)
                .allSatisfy(course -> {
                    assertThat(course.getRoutePoints()).hasSize(6);
                    assertThat(course.getElements()).hasSize(3);
                    assertThat(course.getOwner().getDisplayName()).isNotBlank();
                });
    }
}
