package com.coco.server.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

/// The other suites switch guest issuance on so they can authenticate without
/// an OAuth round trip. This one deliberately does not, which is what pins the
/// production default: an account has to come from a social provider, or it
/// cannot survive the loss of the device that made it.
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class GuestIssuanceDisabledTest {
    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

    @Autowired
    private MockMvc mockMvc;

    @Test
    void guestIssuanceIsOffUnlessTurnedOn() throws Exception {
        mockMvc.perform(post("/api/v1/auth/guest"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("AUTH_GUEST_DISABLED"));
    }
}
