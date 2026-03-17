package com.ksoot.spark.sales;

import static org.apache.spark.sql.functions.col;
import static org.apache.spark.sql.functions.sum;

import com.ksoot.spark.common.connector.MongoConnector;
import com.ksoot.spark.common.util.SparkUtils;
import com.ksoot.spark.sales.conf.JobProperties;
import com.ksoot.spark.sales.pipeline.SalesReportPipelineTemplate;
import java.util.ArrayList;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.RowFactory;
import org.apache.spark.sql.SparkSession;
import org.apache.spark.sql.types.DataTypes;
import org.apache.spark.sql.types.StructType;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class SparkPipelineExecutor {

  private final SalesReportPipelineTemplate pipelineTemplate;

  public SparkPipelineExecutor(
      final SparkSession sparkSession,
      final JobProperties jobProperties,
      final MongoConnector mongoConnector) {
    this.sparkSession = sparkSession;
    this.jobProperties = jobProperties;
    this.mongoConnector = mongoConnector;
    this.pipelineTemplate =
        new SalesReportPipelineTemplate() {
          @Override
          protected Dataset<Row> loadSales() {
            Dataset<Row> salesDataset = SparkPipelineExecutor.this.mongoConnector.read("sales");
            SparkUtils.logDataset("Sales Dataset", salesDataset);
            return salesDataset;
          }

          @Override
          protected Dataset<Row> aggregateSales(final Dataset<Row> salesDataset) {
            final String statementMonth =
                SparkPipelineExecutor.this.jobProperties.getMonth().toString();
            return salesDataset
                .filter(col("timestamp").startsWith(statementMonth))
                .withColumn("date", col("timestamp").substr(0, 10))
                .withColumn(
                    "sale_amount",
                    col("price")
                        .cast(DataTypes.DoubleType)
                        .multiply(col("quantity").cast(DataTypes.IntegerType)))
                .groupBy("product_id", "date")
                .agg(sum("sale_amount").alias("daily_sale_amount"));
          }

          @Override
          protected Dataset<Row> loadProducts() {
            Dataset<Row> productsDataset = SparkPipelineExecutor.this.productsDataset();
            SparkUtils.logDataset("Products Dataset", productsDataset);
            return productsDataset;
          }

          @Override
          protected Dataset<Row> buildReport(
              final Dataset<Row> aggregatedSales, final Dataset<Row> productsDataset) {
            Dataset<Row> monthlySalesReport =
                aggregatedSales
                    .join(
                        productsDataset,
                        aggregatedSales
                            .col("product_id")
                            .equalTo(productsDataset.col("product_id")))
                    .select(
                        productsDataset.col("product_name").as("product"),
                        aggregatedSales.col("date"),
                        aggregatedSales.col("daily_sale_amount").alias("sale"))
                    .orderBy(col("product_name"), col("date"));
            SparkUtils.logDataset("Sales report", monthlySalesReport);
            return monthlySalesReport;
          }

          @Override
          protected void persist(final Dataset<Row> reportDataset) {
            final String statementMonth =
                SparkPipelineExecutor.this.jobProperties.getMonth().toString();
            final String salesReportCollection = "sales_report_" + statementMonth.replace('-', '_');
            SparkPipelineExecutor.this.mongoConnector.write(reportDataset, salesReportCollection);
          }
        };
  }

  private final SparkSession sparkSession;

  private final JobProperties jobProperties;

  private final MongoConnector mongoConnector;

  public void execute() {
    log.info("Generating Sales report for month: {}", this.jobProperties.getMonth());
    this.pipelineTemplate.run();
    // this.fileConnector.write(monthlySalesReport); // For testing
  }

  private Dataset<Row> productsDataset() {
    final List<Row> rows = new ArrayList<>();
    rows.add(RowFactory.create("1001", "TV"));
    rows.add(RowFactory.create("1002", "Mobile"));
    rows.add(RowFactory.create("1003", "Table"));
    rows.add(RowFactory.create("1004", "Chair"));
    rows.add(RowFactory.create("1005", "Sofa"));
    rows.add(RowFactory.create("1006", "AC"));
    rows.add(RowFactory.create("1007", "Bed"));
    rows.add(RowFactory.create("1008", "Charger"));
    rows.add(RowFactory.create("1009", "Laptop"));
    rows.add(RowFactory.create("1010", "Tablet"));

    final StructType schema =
        new StructType()
            .add("product_id", DataTypes.StringType, false)
            .add("product_name", DataTypes.StringType, false);

    return this.sparkSession.createDataFrame(rows, schema);
  }
}
