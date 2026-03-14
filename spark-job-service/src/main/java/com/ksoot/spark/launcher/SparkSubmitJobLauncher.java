package com.ksoot.spark.launcher;

import static com.ksoot.spark.util.Constants.*;

import com.ksoot.problem.core.Problems;
import com.ksoot.spark.conf.SparkJobProperties;
import com.ksoot.spark.conf.SparkLauncherProperties;
import com.ksoot.spark.dto.JobLaunchRequest;
import jakarta.annotation.PreDestroy;
import java.io.*;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Consumer;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Slf4j
@Component
public class SparkSubmitJobLauncher extends AbstractSparkJobLauncher {

  private final KafkaTemplate<String, String> kafkaTemplate;

  private final ExecutorService executor;

  private final String jobStopTopic;

  public SparkSubmitJobLauncher(
      @Qualifier("sparkProperties") final Properties sparkProperties,
      final SparkLauncherProperties sparkLauncherProperties,
      final KafkaTemplate<String, String> kafkaTemplate,
      @Value("${spark-launcher.job-stop-topic}") final String jobStopTopic) {
    super(sparkProperties, sparkLauncherProperties);
    this.kafkaTemplate = kafkaTemplate;
    this.jobStopTopic = jobStopTopic;
    this.executor = Executors.newCachedThreadPool();
  }

  public void startJob(final JobLaunchRequest jobLaunchRequest) {
    log.info("============================================================");

    final SparkJobProperties sparkJobProperties =
        Optional.ofNullable(
                this.sparkLauncherProperties.getJobs().get(jobLaunchRequest.getJobName()))
            .orElseThrow(
                () ->
                    Problems.newInstance(
                        String.format(
                            "Invalid Job name: %s. Allowed values: %s",
                            jobLaunchRequest.getJobName(),
                            String.join(", ", this.sparkLauncherProperties.getJobs().keySet()))));
    final Properties sparkConfigurations =
        this.sparkConfigurations(sparkJobProperties, jobLaunchRequest.getSparkConfigs());

    final Map<String, Object> envVars = this.environmentVariables(sparkJobProperties);

    final Map<String, String> jobArgs = new LinkedHashMap<>(jobLaunchRequest.jobArgs());
    jobArgs.put(CORRELATION_ID, jobLaunchRequest.getCorrelationId());
    jobArgs.put(PERSIST_JOB, String.valueOf(this.sparkLauncherProperties.isPersistJobs()));

    final List<String> sparkSubmitCommand =
        SparkSubmitCommand.jobName(jobLaunchRequest.getJobName())
            .mainClass(sparkJobProperties.getMainClassName())
            .sparkConfigurations(sparkConfigurations)
            .jobArgs(jobArgs)
            .environmentVariables(envVars)
            .jarFile(sparkJobProperties.getJarFile())
            .buildCommandArgs();

    log.info("spark-submit command: {}", String.join(" ", sparkSubmitCommand));

    try {
      CompletableFuture<Process> process = this.sparkSubmit(sparkSubmitCommand);

      process.thenAccept(
          p ->
              log.info(
                  "spark-submit completed with exitValue: {}, Command status: {} for job name: {} and correlation id: {}. "
                      + "Command status does not represent actual Job status, look into application logs or Driver POD logs for details",
                  p.exitValue(),
                  (p.exitValue() == 0 ? "SUCCESS" : "FAILURE"),
                  jobLaunchRequest.getJobName(),
                  jobLaunchRequest.getCorrelationId()));
    } catch (final IOException | InterruptedException e) {
      throw new ResponseStatusException(
          HttpStatus.INTERNAL_SERVER_ERROR,
          "Something went wrong while executing spark-submit command. Please look into logs for details.",
          e);
    }

    log.info("============================================================");
  }

  private CompletableFuture<Process> sparkSubmit(final List<String> sparkSubmitCommand)
      throws IOException, InterruptedException {

    final File directory = new File(this.sparkLauncherProperties.getSparkHome());

    final ProcessBuilder processBuilder =
        new ProcessBuilder(sparkSubmitCommand).directory(directory);

    final Process process;
    // Start the process
    if (this.sparkLauncherProperties.isCaptureJobsLogs()) {
      process = processBuilder.inheritIO().start();
      final StreamGobbler outputGobbler = new StreamGobbler(process.getInputStream(), log::info);
      final StreamGobbler errorGobbler = new StreamGobbler(process.getErrorStream(), log::error);
      executor.submit(outputGobbler);
      executor.submit(errorGobbler);
    } else {
      process = processBuilder.start();
    }

    return process.onExit();
  }

  static class StreamGobbler implements Runnable {
    private final InputStream inputStream;
    private final Consumer<String> consumer;

    StreamGobbler(final InputStream inputStream, final Consumer<String> consumer) {
      this.inputStream = inputStream;
      this.consumer = consumer;
    }

    @Override
    public void run() {
      new BufferedReader(new InputStreamReader(inputStream)).lines().forEach(consumer);
    }
  }

  @Override
  public void stopJob(final String jobCorrelationId) {
    this.kafkaTemplate.send(this.jobStopTopic, jobCorrelationId);
  }

  @PreDestroy
  void shutdownExecutor() {
    this.executor.shutdownNow();
  }
}
