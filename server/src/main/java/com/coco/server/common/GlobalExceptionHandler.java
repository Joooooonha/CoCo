package com.coco.server.common;

import com.coco.server.auth.social.SocialProviderException;
import com.coco.server.common.http.RequestBodyTooLargeException;
import com.coco.server.storage.StorageUnavailableException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger LOGGER = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiErrorResponse> handleNotFound(ResourceNotFoundException exception) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(
                ApiErrorResponse.of(HttpStatus.NOT_FOUND.value(), exception.getCode(), exception.getMessage())
        );
    }

    @ExceptionHandler(BadRequestException.class)
    public ResponseEntity<ApiErrorResponse> handleBadRequest(BadRequestException exception) {
        return ResponseEntity.badRequest().body(
                ApiErrorResponse.of(HttpStatus.BAD_REQUEST.value(), exception.getCode(), exception.getMessage())
        );
    }

    @ExceptionHandler(ForbiddenOperationException.class)
    public ResponseEntity<ApiErrorResponse> handleForbidden(ForbiddenOperationException exception) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(
                ApiErrorResponse.of(HttpStatus.FORBIDDEN.value(), exception.getCode(), exception.getMessage())
        );
    }

    /// The provider's own error text is kept in server logs only.
    @ExceptionHandler(SocialProviderException.class)
    public ResponseEntity<ApiErrorResponse> handleSocialProvider(SocialProviderException exception) {
        LOGGER.warn("Social provider rejected the login attempt", exception);
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(
                ApiErrorResponse.of(
                        HttpStatus.UNAUTHORIZED.value(),
                        "AUTH_PROVIDER_REJECTED",
                        "소셜 로그인에 실패했습니다. 다시 시도해 주세요."
                )
        );
    }

    @ExceptionHandler(PayloadTooLargeException.class)
    public ResponseEntity<ApiErrorResponse> handlePayloadTooLarge(PayloadTooLargeException exception) {
        return ResponseEntity.status(HttpStatus.CONTENT_TOO_LARGE).body(
                ApiErrorResponse.of(
                        HttpStatus.CONTENT_TOO_LARGE.value(),
                        exception.getCode(),
                        exception.getMessage()
                )
        );
    }

    /// Photo endpoints answer with a clear reason when storage has no credentials
    /// rather than surfacing an internal failure.
    @ExceptionHandler(StorageUnavailableException.class)
    public ResponseEntity<ApiErrorResponse> handleStorageUnavailable(StorageUnavailableException exception) {
        LOGGER.warn("Object storage is not configured", exception);
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(
                ApiErrorResponse.of(
                        HttpStatus.SERVICE_UNAVAILABLE.value(),
                        "PHOTO_STORAGE_UNAVAILABLE",
                        "사진 기능을 사용할 수 없어요. 잠시 후 다시 시도해 주세요."
                )
        );
    }

    @ExceptionHandler(ConflictException.class)
    public ResponseEntity<ApiErrorResponse> handleConflict(ConflictException exception) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(
                ApiErrorResponse.of(HttpStatus.CONFLICT.value(), exception.getCode(), exception.getMessage())
        );
    }

    @ExceptionHandler({MethodArgumentNotValidException.class, MethodArgumentTypeMismatchException.class})
    public ResponseEntity<ApiErrorResponse> handleInvalidRequest(Exception exception) {
        return ResponseEntity.badRequest().body(
                ApiErrorResponse.of(HttpStatus.BAD_REQUEST.value(), "INVALID_REQUEST", "요청 값을 확인해 주세요.")
        );
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiErrorResponse> handleUnreadableRequest(HttpMessageNotReadableException exception) {
        if (hasCause(exception, RequestBodyTooLargeException.class)) {
            return ResponseEntity.status(HttpStatus.CONTENT_TOO_LARGE).body(
                    ApiErrorResponse.of(
                            HttpStatus.CONTENT_TOO_LARGE.value(),
                            "REQUEST_BODY_TOO_LARGE",
                            "요청 본문이 너무 큽니다."
                    )
            );
        }

        return ResponseEntity.badRequest().body(
                ApiErrorResponse.of(HttpStatus.BAD_REQUEST.value(), "INVALID_REQUEST", "요청 값을 확인해 주세요.")
        );
    }

    private boolean hasCause(Throwable throwable, Class<? extends Throwable> causeType) {
        Throwable current = throwable;
        while (current != null) {
            if (causeType.isInstance(current)) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }
}
