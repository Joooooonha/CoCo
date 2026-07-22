package com.coco.server.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
