package com.coco.server.course;

public record ReactionCountsResponse(int like, int hard, int scenic) {
    static ReactionCountsResponse empty() {
        return new ReactionCountsResponse(0, 0, 0);
    }
}
