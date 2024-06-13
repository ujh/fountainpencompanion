require "rails_helper"

describe Pens::UpdateModelMicroCluster do
  it "does nothing if no model was assigned" do
    micro_cluster = create(:pens_model_micro_cluster)

    expect { subject.perform(micro_cluster.id) }.not_to change(
      Pens::UpdateModel.jobs,
      :length
    )
  end

  it "schedules the model update job if model assigned" do
    micro_cluster =
      create(:pens_model_micro_cluster, model: create(:pens_model))

    expect { subject.perform(micro_cluster.id) }.to change(
      Pens::UpdateModel.jobs,
      :length
    ).by(1)
  end
end
