// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { SwabCard } from "./SwabCard";
import { formatISO9075 } from "date-fns";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<SwabCard />", () => {
  it("renders a Private-badge if private", () => {
    const { getByText } = setup(
      <SwabCard
        id="1"
        archived={false}
        brand_name="Pilot"
        ink_name="Blue"
        private={true}
        hiddenFields={[]}
      />
    );

    expect(getByText("Private")).toBeInTheDocument();
  });

  it("renders no Private-badge if public", () => {
    const { queryByText } = setup(
      <SwabCard
        id="1"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(queryByText("Private")).not.toBeInTheDocument();
  });

  it("renders a Swabbed-badge if swabbed", () => {
    const { getByText } = setup(
      <SwabCard
        id="1"
        archived={false}
        brand_name="Pilot"
        ink_name="Blue"
        swabbed={true}
        hiddenFields={[]}
      />
    );

    expect(getByText("Swabbed")).toBeInTheDocument();
  });

  it("renders no Swabbed-badge if not swabbed", () => {
    const { queryByText } = setup(
      <SwabCard
        id="1"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(queryByText("Swabbed")).not.toBeInTheDocument();
  });

  it("renders a Used-badge if used", () => {
    const { getByText } = setup(
      <SwabCard
        id="1"
        archived={false}
        brand_name="Pilot"
        ink_name="Blue"
        used={true}
        hiddenFields={[]}
      />
    );

    expect(getByText("Used")).toBeInTheDocument();
  });

  it("renders no Used-badge if unused", () => {
    const { queryByText } = setup(
      <SwabCard
        id="1"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(queryByText("Used")).not.toBeInTheDocument();
  });

  it("renders a badge with kind info if set", () => {
    const { getByText } = setup(
      <SwabCard
        id="1"
        archived={false}
        brand_name="Pilot"
        ink_name="Blue"
        kind="bottle"
        used={true}
        hiddenFields={[]}
      />
    );

    expect(getByText("bottle")).toBeInTheDocument();
  });

  it("doesn't render the kind-badge if not set", () => {
    const { queryByText } = setup(
      <SwabCard
        id="1"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(queryByText("bottle")).not.toBeInTheDocument();
    expect(queryByText("cartridge")).not.toBeInTheDocument();
    expect(queryByText("sample")).not.toBeInTheDocument();
    expect(queryByText("swab")).not.toBeInTheDocument();
  });

  it("renders custom tags", () => {
    const { getByText } = setup(
      <SwabCard
        id="1"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        tags={[
          { id: "1", name: "custom" },
          { id: "2", name: "bespoke" },
          { id: "3", name: "personal" }
        ]}
        hiddenFields={[]}
      />
    );

    expect(getByText("custom")).toBeInTheDocument();
    expect(getByText("bespoke")).toBeInTheDocument();
    expect(getByText("personal")).toBeInTheDocument();
  });

  it("renders a link to the ink details page if an ink ID exists", () => {
    const { getAllByRole } = setup(
      <SwabCard
        id="1"
        ink_id="1"
        color="#000"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    const [inkLink] = getAllByRole("link");

    expect(inkLink.getAttribute("href")).toEqual("/inks/1");
  });

  it("renders a maker heading if there's a maker", () => {
    const { getByText } = setup(
      <SwabCard
        id="1"
        ink_id="1"
        color="#000"
        archived={false}
        brand_name="Pilot"
        maker="Pilot"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(getByText("Maker")).toBeInTheDocument();
  });

  it("renders no maker heading if there's no maker", () => {
    const { queryByText } = setup(
      <SwabCard
        id="1"
        ink_id="1"
        color="#000"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(queryByText("Maker")).not.toBeInTheDocument();
  });

  it("renders comments", () => {
    const { getByText } = setup(
      <SwabCard
        id="1"
        ink_id="1"
        color="#000"
        archived={false}
        brand_name="Pilot"
        comment="This is a comment"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(getByText("This is a comment")).toBeInTheDocument();
  });

  it("renders usage stats", () => {
    const { getByText, getByTestId } = setup(
      <SwabCard
        id="1"
        ink_id="1"
        color="#000"
        archived={false}
        brand_name="Pilot"
        daily_usage={10}
        last_used_on={formatISO9075(new Date(), { representation: "date" })}
        usage={1}
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(getByText("Usage")).toBeInTheDocument();
    expect(getByTestId("usage")).toBeInTheDocument();
    const usageElement = getByTestId("usage");
    expect(usageElement.textContent).toBe(
      "1 inked - last used today (10 daily usages)"
    );
  });

  it("doesn't render a usage header if there are no stats", () => {
    const { queryByText } = setup(
      <SwabCard
        id="1"
        ink_id="1"
        color="#000"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(queryByText("Usage")).not.toBeInTheDocument();
  });

  it("renders a private comment heading if there's a private comment", () => {
    const { getByText } = setup(
      <SwabCard
        id="1"
        ink_id="1"
        color="#000"
        archived={false}
        brand_name="Pilot"
        private_comment="Secret"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(getByText("Private comment")).toBeInTheDocument();
    expect(getByText("Secret")).toBeInTheDocument();
  });

  it("renders no maker heading if there's no maker", () => {
    const { queryByText } = setup(
      <SwabCard
        id="1"
        ink_id="1"
        color="#000"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        hiddenFields={[]}
      />
    );

    expect(queryByText("Maker")).not.toBeInTheDocument();
  });

  it("hides as expected if given hidden fields", () => {
    const { queryByText } = setup(
      <SwabCard
        id="1"
        ink_id="1"
        color="#000"
        archived={false}
        brand_name="Pilot"
        ink_name="Black"
        kind="bottle"
        maker="Maker"
        comment="Public"
        private_comment="Secret"
        created_at="2023-01-01"
        tags={[
          { id: "1", name: "custom" },
          { id: "2", name: "bespoke" },
          { id: "3", name: "personal" }
        ]}
        used={true}
        swabbed={true}
        hiddenFields={[
          "maker",
          "kind",
          "usage",
          "used",
          "swabbed",
          "comment",
          "private_comment",
          "tags",
          "created_at"
        ]}
      />
    );

    expect(queryByText("Maker")).not.toBeInTheDocument();
    expect(queryByText("Secret")).not.toBeInTheDocument();
    expect(queryByText("Maker")).not.toBeInTheDocument();
    expect(queryByText("Public")).not.toBeInTheDocument();
    expect(queryByText("custom")).not.toBeInTheDocument();
    expect(queryByText("bespoke")).not.toBeInTheDocument();
    expect(queryByText("personal")).not.toBeInTheDocument();
    expect(queryByText("bottle")).not.toBeInTheDocument();
    expect(queryByText("Used")).not.toBeInTheDocument();
    expect(queryByText("Swabbed")).not.toBeInTheDocument();
    expect(queryByText("Added On")).not.toBeInTheDocument();
  });
});
