package com.coco.server.api;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/// Covers the presigned upload flow end to end with storage stubbed out, so the
/// ownership, size and content-type rules are exercised without network access.
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@Import(ElementPhotoIntegrationTest.StubStorageConfig.class)
class ElementPhotoIntegrationTest {
    @TestConfiguration
    static class StubStorageConfig {
        @Bean
        @Primary
        InMemoryObjectStorage inMemoryObjectStorage() {
            return new InMemoryObjectStorage();
        }
    }

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private InMemoryObjectStorage storage;

    @BeforeEach
    void resetStorage() {
        storage.clear();
    }

    @Test
    void photoIsAttachedOnlyAfterTheUploadIsConfirmed() throws Exception {
        String authorization = issueGuestAuthorization();
        JsonNode course = createCourse(authorization, "사진 코스");
        String courseId = course.get("id").asText();
        String elementId = course.get("elements").get(0).get("id").asText();

        String ticketBody = mockMvc.perform(post(photoPath(courseId, elementId) + "/upload-url")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/jpeg\",\"contentLength\":204800}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.uploadURL").isNotEmpty())
                .andExpect(jsonPath("$.contentType").value("image/jpeg"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String objectKey = objectKeyOf(ticketBody);

        // The ticket alone must not attach anything.
        mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.elements[0].photoURL").doesNotExist());

        mockMvc.perform(put(photoPath(courseId, elementId))
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/jpeg\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PHOTO_NOT_UPLOADED"));

        storage.put(objectKey, 204_800);

        mockMvc.perform(put(photoPath(courseId, elementId))
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/jpeg\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.photoURL").isNotEmpty());

        mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.elements[0].photoURL").isNotEmpty());
    }

    @Test
    void deletingThePhotoClearsBothTheRowAndTheStoredObject() throws Exception {
        String authorization = issueGuestAuthorization();
        JsonNode course = createCourse(authorization, "사진 삭제 코스");
        String courseId = course.get("id").asText();
        String elementId = course.get("elements").get(0).get("id").asText();
        String objectKey = attachPhoto(authorization, courseId, elementId);

        mockMvc.perform(delete(photoPath(courseId, elementId)).header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isNoContent());

        assertFalse(storage.contains(objectKey), "삭제 후에도 객체가 남아 있으면 안 된다");
        mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.elements[0].photoURL").doesNotExist());

        // Deleting again is a no-op rather than an error.
        mockMvc.perform(delete(photoPath(courseId, elementId)).header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isNoContent());
    }

    @Test
    void deletingTheCourseRemovesStoredPhotos() throws Exception {
        String authorization = issueGuestAuthorization();
        JsonNode course = createCourse(authorization, "코스 삭제 시 사진 정리");
        String courseId = course.get("id").asText();
        String elementId = course.get("elements").get(0).get("id").asText();
        String objectKey = attachPhoto(authorization, courseId, elementId);
        assertTrue(storage.contains(objectKey));

        mockMvc.perform(delete("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isNoContent());

        assertFalse(storage.contains(objectKey), "코스를 지우면 저장된 사진도 사라져야 한다");
    }

    @Test
    void ticketRejectsUnsupportedTypesAndOversizedPhotos() throws Exception {
        String authorization = issueGuestAuthorization();
        JsonNode course = createCourse(authorization, "사진 제한 코스");
        String courseId = course.get("id").asText();
        String elementId = course.get("elements").get(0).get("id").asText();

        mockMvc.perform(post(photoPath(courseId, elementId) + "/upload-url")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/gif\",\"contentLength\":1024}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("PHOTO_CONTENT_TYPE_UNSUPPORTED"));

        mockMvc.perform(post(photoPath(courseId, elementId) + "/upload-url")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/jpeg\",\"contentLength\":6291456}"))
                .andExpect(status().isContentTooLarge())
                .andExpect(jsonPath("$.code").value("PHOTO_TOO_LARGE"));
    }

    /// A client could declare a small size to get a ticket and then upload a
    /// large file, so confirmation re-checks the stored size.
    @Test
    void confirmationRejectsAnObjectLargerThanTheLimit() throws Exception {
        String authorization = issueGuestAuthorization();
        JsonNode course = createCourse(authorization, "크기 재검사 코스");
        String courseId = course.get("id").asText();
        String elementId = course.get("elements").get(0).get("id").asText();

        String ticketBody = mockMvc.perform(post(photoPath(courseId, elementId) + "/upload-url")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/jpeg\",\"contentLength\":1024}"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String objectKey = objectKeyOf(ticketBody);
        storage.put(objectKey, 8L * 1024 * 1024);

        mockMvc.perform(put(photoPath(courseId, elementId))
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/jpeg\"}"))
                .andExpect(status().isContentTooLarge())
                .andExpect(jsonPath("$.code").value("PHOTO_TOO_LARGE"));

        assertFalse(storage.contains(objectKey), "한도를 넘긴 업로드는 저장소에서 지워져야 한다");
    }

    @Test
    void onlyTheOwnerCanManagePhotos() throws Exception {
        String owner = issueGuestAuthorization();
        String stranger = issueGuestAuthorization();
        JsonNode course = createCourse(owner, "소유자 전용 사진 코스");
        String courseId = course.get("id").asText();
        String elementId = course.get("elements").get(0).get("id").asText();

        mockMvc.perform(post(photoPath(courseId, elementId) + "/upload-url")
                        .header(HttpHeaders.AUTHORIZATION, stranger)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/jpeg\",\"contentLength\":1024}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("COURSE_OWNER_ONLY"));

        mockMvc.perform(delete(photoPath(courseId, elementId)).header(HttpHeaders.AUTHORIZATION, stranger))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("COURSE_OWNER_ONLY"));
    }

    @Test
    void replacingAJpegWithAHeicLeavesNoOrphanedObject() throws Exception {
        String authorization = issueGuestAuthorization();
        JsonNode course = createCourse(authorization, "형식 교체 코스");
        String courseId = course.get("id").asText();
        String elementId = course.get("elements").get(0).get("id").asText();
        String jpegKey = attachPhoto(authorization, courseId, elementId);

        String ticketBody = mockMvc.perform(post(photoPath(courseId, elementId) + "/upload-url")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/heic\",\"contentLength\":102400}"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String heicKey = objectKeyOf(ticketBody);
        storage.put(heicKey, 102_400);

        mockMvc.perform(put(photoPath(courseId, elementId))
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/heic\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.photoURL").isNotEmpty());

        assertFalse(storage.contains(jpegKey), "교체된 이전 형식의 객체는 남으면 안 된다");
        assertTrue(storage.contains(heicKey));
    }

    private String attachPhoto(String authorization, String courseId, String elementId) throws Exception {
        String ticketBody = mockMvc.perform(post(photoPath(courseId, elementId) + "/upload-url")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/jpeg\",\"contentLength\":102400}"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String objectKey = objectKeyOf(ticketBody);
        storage.put(objectKey, 102_400);

        mockMvc.perform(put(photoPath(courseId, elementId))
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"contentType\":\"image/jpeg\"}"))
                .andExpect(status().isOk());
        return objectKey;
    }

    private String photoPath(String courseId, String elementId) {
        return "/api/v1/courses/" + courseId + "/elements/" + elementId + "/photo";
    }

    /// The key is an implementation detail of the service, so the test recovers
    /// it from the presigned URL instead of rebuilding the naming rule.
    private String objectKeyOf(String ticketBody) {
        String uploadURL = objectMapper.readTree(ticketBody).get("uploadURL").asText();
        int start = uploadURL.indexOf("/upload/") + "/upload/".length();
        int end = uploadURL.indexOf('?', start);
        return uploadURL.substring(start, end);
    }

    private JsonNode createCourse(String authorization, String name) throws Exception {
        String body = mockMvc.perform(post("/api/v1/courses")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "summary": "사진 테스트용 코스",
                                  "difficulty": "EASY",
                                  "distanceMeters": 3200,
                                  "estimatedDurationSeconds": 1500,
                                  "routeSource": "PLANNED_MAPKIT",
                                  "routePoints": [
                                    {"sequence":0,"latitude":37.526,"longitude":126.93},
                                    {"sequence":1,"latitude":37.529,"longitude":126.94}
                                  ],
                                  "elements": [
                                    {"category":"VIEW","latitude":37.527,"longitude":126.935,
                                     "distanceFromStartMeters":400,"title":"강변 전망","description":"노을이 잘 보이는 구간"}
                                  ]
                                }
                                """.formatted(name)))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return objectMapper.readTree(body);
    }

    private String issueGuestAuthorization() throws Exception {
        String guestBody = mockMvc.perform(post("/api/v1/auth/guest"))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return "Bearer " + objectMapper.readTree(guestBody).get("token").asText();
    }
}
