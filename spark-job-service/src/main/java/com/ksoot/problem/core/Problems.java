package com.ksoot.problem.core;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

public class Problems {
  /**
   * Returns a supplier that throws a 404 Not Found exception, for use with Optional.orElseThrow().
   */
  public static ResponseStatusException notFound() {
    return new ResponseStatusException(HttpStatus.NOT_FOUND, "Resource not found");
  }

  /** Create a new exception with a custom message and 400 Bad Request status. */
  public static ResponseStatusException newInstance(String message) {
    return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
  }
}
