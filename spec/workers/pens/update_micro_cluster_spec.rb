require "rails_helper"

describe Pens::UpdateMicroCluster do
  it "does nothing if no model variant was assigned" do
    micro_cluster = create(:pens_micro_cluster)

    expect { subject.perform(micro_cluster.id) }.not_to change(
      Pens::UpdateModelVariant.jobs,
      :length
    )
  end

  it "schedules the model variant update job if model variant assigned" do
    micro_cluster = create(:pens_micro_cluster, model_variant: create(:pens_model_variant))

    expect { subject.perform(micro_cluster.id) }.to change(
      Pens::UpdateModelVariant.jobs,
      :length
    ).by(1)
  end
end
