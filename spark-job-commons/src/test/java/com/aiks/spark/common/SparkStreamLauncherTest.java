package com.aiks.spark.common;

import org.apache.spark.sql.streaming.DataStreamWriter;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.core.task.TaskExecutor;

class SparkStreamLauncherTest {

  @Test
  void testStartStreamExecutesTask() {
    TaskExecutor taskExecutor = Mockito.mock(TaskExecutor.class);
    SparkExecutionManager manager = Mockito.mock(SparkExecutionManager.class);
    SparkStreamLauncher launcher = new SparkStreamLauncher(manager, taskExecutor);
    DataStreamWriter<?> writer = Mockito.mock(DataStreamWriter.class);
    launcher.startStream(writer);
    Mockito.verify(taskExecutor).execute(Mockito.any());
  }
}
