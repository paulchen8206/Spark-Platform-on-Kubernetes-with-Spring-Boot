package com.ksoot.spark.common;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.core.task.TaskExecutor;
import org.apache.spark.sql.streaming.DataStreamWriter;

import static org.junit.jupiter.api.Assertions.*;

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
