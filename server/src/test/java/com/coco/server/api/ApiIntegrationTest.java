package com.coco.server.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.coco.server.course.CourseRepository;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class ApiIntegrationTest {
    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private CourseRepository courseRepository;

    @Test
    void guestCanAuthenticateAndReadCourses() throws Exception {
        String guestBody = mockMvc.perform(post("/api/v1/auth/guest"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.user.accountType").value("GUEST"))
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode guest = objectMapper.readTree(guestBody);
        String authorization = "Bearer " + guest.get("token").asText();

        mockMvc.perform(get("/api/v1/courses").header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.items[0].name").value("한강 노을 라인"))
                .andExpect(jsonPath("$.items[0].routePoints.length()").value(6))
                .andExpect(jsonPath("$.items[0].elements.length()").value(3));

        mockMvc.perform(get("/api/v1/courses/10000000-0000-0000-0000-000000000002")
                        .header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("서울숲 리커버리 루프"));
    }

    @Test
    void protectedEndpointRejectsMissingAndInvalidTokens() throws Exception {
        mockMvc.perform(get("/api/v1/courses"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"));

        mockMvc.perform(get("/api/v1/courses")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer invalid"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTH_TOKEN_INVALID"));
    }

    @Test
    void missingCourseReturnsStableErrorCode() throws Exception {
        String guestBody = mockMvc.perform(post("/api/v1/auth/guest"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String token = objectMapper.readTree(guestBody).get("token").asText();

        mockMvc.perform(get("/api/v1/courses/ffffffff-ffff-ffff-ffff-ffffffffffff")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("COURSE_NOT_FOUND"));
    }

    @Test
    void scrapLifecycleIsIdempotentAndPerUser() throws Exception {
        String firstUser = issueGuestAuthorization();
        String secondUser = issueGuestAuthorization();
        String courseId = "10000000-0000-0000-0000-000000000001";

        mockMvc.perform(put("/api/v1/courses/" + courseId + "/scrap").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isNoContent());
        mockMvc.perform(put("/api/v1/courses/" + courseId + "/scrap").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.scrapCount").value(1))
                .andExpect(jsonPath("$.isScrapped").value(true));

        mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, secondUser))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.scrapCount").value(1))
                .andExpect(jsonPath("$.isScrapped").value(false));

        mockMvc.perform(get("/api/v1/me/scraps").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].id").value(courseId))
                .andExpect(jsonPath("$.items[0].isScrapped").value(true));

        mockMvc.perform(delete("/api/v1/courses/" + courseId + "/scrap").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isNoContent());
        mockMvc.perform(delete("/api/v1/courses/" + courseId + "/scrap").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.scrapCount").value(0))
                .andExpect(jsonPath("$.isScrapped").value(false));

        mockMvc.perform(get("/api/v1/me/scraps").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    @Test
    void reactionLifecycleIsIdempotentAndPerUser() throws Exception {
        String firstUser = issueGuestAuthorization();
        String secondUser = issueGuestAuthorization();
        String courseId = "10000000-0000-0000-0000-000000000002";

        mockMvc.perform(put("/api/v1/courses/" + courseId + "/reactions/LIKE").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isNoContent());
        mockMvc.perform(put("/api/v1/courses/" + courseId + "/reactions/LIKE").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isNoContent());
        mockMvc.perform(put("/api/v1/courses/" + courseId + "/reactions/SCENIC").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isNoContent());
        mockMvc.perform(put("/api/v1/courses/" + courseId + "/reactions/LIKE").header(HttpHeaders.AUTHORIZATION, secondUser))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reactionCounts.like").value(2))
                .andExpect(jsonPath("$.reactionCounts.hard").value(0))
                .andExpect(jsonPath("$.reactionCounts.scenic").value(1))
                .andExpect(jsonPath("$.myReactions.length()").value(2));

        mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, secondUser))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reactionCounts.like").value(2))
                .andExpect(jsonPath("$.myReactions.length()").value(1))
                .andExpect(jsonPath("$.myReactions[0]").value("LIKE"));

        mockMvc.perform(delete("/api/v1/courses/" + courseId + "/reactions/LIKE").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isNoContent());
        mockMvc.perform(delete("/api/v1/courses/" + courseId + "/reactions/LIKE").header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, firstUser))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reactionCounts.like").value(1))
                .andExpect(jsonPath("$.reactionCounts.scenic").value(1))
                .andExpect(jsonPath("$.myReactions.length()").value(1))
                .andExpect(jsonPath("$.myReactions[0]").value("SCENIC"));
    }

    @Test
    void invalidReactionTypeIsRejected() throws Exception {
        String authorization = issueGuestAuthorization();

        mockMvc.perform(put("/api/v1/courses/10000000-0000-0000-0000-000000000001/reactions/AMAZING")
                        .header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void scrapAndReactionOnMissingCourseReturnNotFound() throws Exception {
        String authorization = issueGuestAuthorization();
        String missingCourse = "ffffffff-ffff-ffff-ffff-ffffffffffff";

        mockMvc.perform(put("/api/v1/courses/" + missingCourse + "/scrap")
                        .header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("COURSE_NOT_FOUND"));

        mockMvc.perform(put("/api/v1/courses/" + missingCourse + "/reactions/LIKE")
                        .header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("COURSE_NOT_FOUND"));
    }

    @Test
    void newGuestHasNoOwnedCourses() throws Exception {
        String authorization = issueGuestAuthorization();

        mockMvc.perform(get("/api/v1/me/courses").header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    @Test
    void ownerCanRegisterCourseAndSeeItInLists() throws Exception {
        String authorization = issueGuestAuthorization();
        UUID courseId = null;

        try {
            String createdBody = mockMvc.perform(post("/api/v1/courses")
                            .header(HttpHeaders.AUTHORIZATION, authorization)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(validCourseJson("퇴근길 야간 러닝")))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.name").value("퇴근길 야간 러닝"))
                    .andExpect(jsonPath("$.locationLabel").value("서울"))
                    .andExpect(jsonPath("$.routePoints.length()").value(3))
                    .andExpect(jsonPath("$.routePoints[0].sequence").value(0))
                    .andExpect(jsonPath("$.elements.length()").value(1))
                    .andExpect(jsonPath("$.scrapCount").value(0))
                    .andReturn()
                    .getResponse()
                    .getContentAsString();
            courseId = UUID.fromString(objectMapper.readTree(createdBody).get("id").asText());

            mockMvc.perform(get("/api/v1/me/courses").header(HttpHeaders.AUTHORIZATION, authorization))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.items.length()").value(1))
                    .andExpect(jsonPath("$.items[0].id").value(courseId.toString()));

            mockMvc.perform(get("/api/v1/courses").header(HttpHeaders.AUTHORIZATION, authorization))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.items.length()").value(3));
        } finally {
            if (courseId != null) {
                courseRepository.deleteById(courseId);
            }
        }
    }

    @Test
    void courseRegistrationRequiresElementsAndValidSequences() throws Exception {
        String authorization = issueGuestAuthorization();

        String withoutElements = validCourseJson("요소 없는 코스").replace(
                elementListJson(),
                "[]"
        );
        mockMvc.perform(post("/api/v1/courses")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(withoutElements))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));

        String duplicatedSequence = validCourseJson("순서 중복 코스").replace(
                "\"sequence\":1",
                "\"sequence\":0"
        );
        mockMvc.perform(post("/api/v1/courses")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(duplicatedSequence))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("ROUTE_POINTS_INVALID"));

        String recordedSource = validCourseJson("기록 소스 코스").replace(
                "PLANNED_MAPKIT",
                "RECORDED_GPS"
        );
        mockMvc.perform(post("/api/v1/courses")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(recordedSource))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("ROUTE_SOURCE_UNSUPPORTED"));
    }

    @Test
    void ownerManagesElementsAndMinimumIsEnforced() throws Exception {
        String authorization = issueGuestAuthorization();
        UUID courseId = null;

        try {
            String createdBody = mockMvc.perform(post("/api/v1/courses")
                            .header(HttpHeaders.AUTHORIZATION, authorization)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(validCourseJson("요소 편집 코스")))
                    .andExpect(status().isCreated())
                    .andReturn()
                    .getResponse()
                    .getContentAsString();
            JsonNode created = objectMapper.readTree(createdBody);
            courseId = UUID.fromString(created.get("id").asText());
            String firstElementId = created.get("elements").get(0).get("id").asText();

            mockMvc.perform(delete("/api/v1/courses/" + courseId + "/elements/" + firstElementId)
                            .header(HttpHeaders.AUTHORIZATION, authorization))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.code").value("ELEMENT_MINIMUM_REQUIRED"));

            String addedBody = mockMvc.perform(post("/api/v1/courses/" + courseId + "/elements")
                            .header(HttpHeaders.AUTHORIZATION, authorization)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"category":"FACILITY","latitude":37.528,"longitude":126.933,
                                     "distanceFromStartMeters":900,"title":"음수대","description":"공원 입구 음수대"}
                                    """))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.category").value("FACILITY"))
                    .andReturn()
                    .getResponse()
                    .getContentAsString();
            String addedElementId = objectMapper.readTree(addedBody).get("id").asText();

            mockMvc.perform(patch("/api/v1/courses/" + courseId + "/elements/" + addedElementId)
                            .header(HttpHeaders.AUTHORIZATION, authorization)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"title\":\"고장난 음수대\"}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.title").value("고장난 음수대"))
                    .andExpect(jsonPath("$.category").value("FACILITY"));

            mockMvc.perform(delete("/api/v1/courses/" + courseId + "/elements/" + addedElementId)
                            .header(HttpHeaders.AUTHORIZATION, authorization))
                    .andExpect(status().isNoContent());

            mockMvc.perform(get("/api/v1/courses/" + courseId).header(HttpHeaders.AUTHORIZATION, authorization))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.elements.length()").value(1));
        } finally {
            if (courseId != null) {
                courseRepository.deleteById(courseId);
            }
        }
    }

    @Test
    void nonOwnerCannotModifySeededCourseElements() throws Exception {
        String authorization = issueGuestAuthorization();
        String seededCourseId = "10000000-0000-0000-0000-000000000001";
        String seededElementId = "12000000-0000-0000-0000-000000000001";

        mockMvc.perform(patch("/api/v1/courses/" + seededCourseId + "/elements/" + seededElementId)
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"탈취 시도\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("COURSE_OWNER_ONLY"));

        mockMvc.perform(delete("/api/v1/courses/" + seededCourseId + "/elements/" + seededElementId)
                        .header(HttpHeaders.AUTHORIZATION, authorization))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("COURSE_OWNER_ONLY"));

        mockMvc.perform(post("/api/v1/courses/" + seededCourseId + "/elements")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"category":"VIEW","latitude":37.5,"longitude":126.9,
                                 "distanceFromStartMeters":10,"title":"불법 요소","description":"소유자 아님"}
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("COURSE_OWNER_ONLY"));
    }

    private String validCourseJson(String name) {
        return """
                {
                  "name": "%s",
                  "summary": "테스트로 등록한 코스",
                  "difficulty": "EASY",
                  "distanceMeters": 3200,
                  "estimatedDurationSeconds": 1500,
                  "routeSource": "PLANNED_MAPKIT",
                  "routePoints": [
                    {"sequence":0,"latitude":37.526,"longitude":126.93},
                    {"sequence":1,"latitude":37.527,"longitude":126.935},
                    {"sequence":2,"latitude":37.529,"longitude":126.94}
                  ],
                  "elements": %s
                }
                """.formatted(name, elementListJson());
    }

    private String elementListJson() {
        return """
                [
                    {"category":"VIEW","latitude":37.527,"longitude":126.935,
                     "distanceFromStartMeters":400,"title":"강변 전망","description":"노을이 잘 보이는 구간"}
                  ]
                """.strip();
    }

    private String issueGuestAuthorization() throws Exception {
        String guestBody = mockMvc.perform(post("/api/v1/auth/guest"))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return "Bearer " + objectMapper.readTree(guestBody).get("token").asText();
    }

    @Test
    void oversizedRequestBodyIsRejectedBeforeApplicationHandling() throws Exception {
        String oversizedJson = "{\"padding\":\"" + "a".repeat(262_144) + "\"}";

        mockMvc.perform(post("/api/v1/auth/guest")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(oversizedJson))
                .andExpect(status().isContentTooLarge())
                .andExpect(jsonPath("$.code").value("REQUEST_BODY_TOO_LARGE"));
    }
}
