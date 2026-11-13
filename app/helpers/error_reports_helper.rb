module ErrorReportsHelper
  def error_report_page_url(error_report)
    case error_report.reportable
    when InkReview
      ink_url(error_report.reportable.macro_cluster)
    when MacroCluster
      ink_url(error_report.reportable)
    when Pens::Model
      pen_model_url(error_report.reportable)
    when Pens::ModelVariant
      pen_variant_url(error_report.reportable)
    end
  end
end
