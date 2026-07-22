package com.coco.server.course;

import java.util.Map;

public record ReactionCountsResponse(int like, int hard, int scenic) {
    static ReactionCountsResponse empty() {
        return new ReactionCountsResponse(0, 0, 0);
    }

    static ReactionCountsResponse from(Map<ReactionType, Long> counts) {
        return new ReactionCountsResponse(
                counts.getOrDefault(ReactionType.LIKE, 0L).intValue(),
                counts.getOrDefault(ReactionType.HARD, 0L).intValue(),
                counts.getOrDefault(ReactionType.SCENIC, 0L).intValue()
        );
    }
}
