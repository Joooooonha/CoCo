package com.coco.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration;

@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
public class CoCoServerApplication {

	public static void main(String[] args) {
		SpringApplication.run(CoCoServerApplication.class, args);
	}

}
