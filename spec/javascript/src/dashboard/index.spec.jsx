import { fireEvent, render, screen } from "@testing-library/react";
import { Dashboard } from "dashboard/index";
import { useDashboardPreferences } from "dashboard/useDashboardPreferences";

jest.mock("dashboard/widget_registry", () => {
  const WidgetA = () => <div data-testid="widget-a">Widget A</div>;
  const WidgetB = () => <div data-testid="widget-b">Widget B</div>;
  const WidgetC = () => <div data-testid="widget-c">Widget C</div>;

  const WIDGET_REGISTRY = [
    { id: "widget_a", label: "Widget A", component: WidgetA },
    { id: "widget_b", label: "Widget B", component: WidgetB },
    { id: "widget_c", label: "Widget C", component: WidgetC }
  ];

  return {
    WIDGET_REGISTRY,
    WIDGET_REGISTRY_MAP: Object.fromEntries(WIDGET_REGISTRY.map((w) => [w.id, w]))
  };
});

const mockSetVisibleWidgetIds = jest.fn();
const mockSaveToServer = jest.fn();

jest.mock("dashboard/useDashboardPreferences", () => ({
  useDashboardPreferences: jest.fn()
}));

function setupPreferences(visibleIds = ["widget_a", "widget_b", "widget_c"]) {
  mockSetVisibleWidgetIds.mockClear();
  mockSaveToServer.mockClear();
  useDashboardPreferences.mockReturnValue({
    visibleWidgetIds: visibleIds,
    setVisibleWidgetIds: mockSetVisibleWidgetIds,
    saveToServer: mockSaveToServer
  });
}

describe("Dashboard", () => {
  it("renders all visible widgets and a Configure button", () => {
    setupPreferences();
    render(<Dashboard />);

    expect(screen.getByTestId("widget-a")).toBeInTheDocument();
    expect(screen.getByTestId("widget-b")).toBeInTheDocument();
    expect(screen.getByTestId("widget-c")).toBeInTheDocument();
    expect(screen.getByLabelText("Configure dashboard")).toHaveTextContent("\u2699 Configure");
  });

  it("shows Done and Reset buttons when configuring", () => {
    setupPreferences();
    render(<Dashboard />);

    fireEvent.click(screen.getByLabelText("Configure dashboard"));

    expect(screen.getByLabelText("Configure dashboard")).toHaveTextContent("Done");
    expect(screen.getByText("Reset to defaults")).toBeInTheDocument();
  });

  it("shows hidden widgets in configure mode", () => {
    setupPreferences(["widget_a"]);
    render(<Dashboard />);

    fireEvent.click(screen.getByLabelText("Configure dashboard"));

    expect(screen.getByLabelText("Add Widget B")).toBeInTheDocument();
    expect(screen.getByLabelText("Add Widget C")).toBeInTheDocument();
  });

  it("does not show hidden widgets outside configure mode", () => {
    setupPreferences(["widget_a"]);
    render(<Dashboard />);

    expect(screen.queryByLabelText("Add Widget B")).not.toBeInTheDocument();
  });

  it("calls setVisibleWidgetIds without the widget on remove", () => {
    setupPreferences(["widget_a", "widget_b", "widget_c"]);
    render(<Dashboard />);

    fireEvent.click(screen.getByLabelText("Configure dashboard"));
    fireEvent.click(screen.getByLabelText("Remove Widget B"));

    expect(mockSetVisibleWidgetIds).toHaveBeenCalledWith(["widget_a", "widget_c"]);
  });

  it("calls setVisibleWidgetIds with widget appended on add", () => {
    setupPreferences(["widget_a"]);
    render(<Dashboard />);

    fireEvent.click(screen.getByLabelText("Configure dashboard"));
    fireEvent.click(screen.getByLabelText("Add Widget B"));

    expect(mockSetVisibleWidgetIds).toHaveBeenCalledWith(["widget_a", "widget_b"]);
  });

  it("calls setVisibleWidgetIds with null on reset", () => {
    setupPreferences(["widget_a"]);
    render(<Dashboard />);

    fireEvent.click(screen.getByLabelText("Configure dashboard"));
    fireEvent.click(screen.getByText("Reset to defaults"));

    expect(mockSetVisibleWidgetIds).toHaveBeenCalledWith(null);
  });

  it("exits configure mode when Done is clicked", () => {
    setupPreferences();
    render(<Dashboard />);

    fireEvent.click(screen.getByLabelText("Configure dashboard"));
    expect(screen.getByText("Reset to defaults")).toBeInTheDocument();

    fireEvent.click(screen.getByLabelText("Configure dashboard"));
    expect(screen.queryByText("Reset to defaults")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Configure dashboard")).toHaveTextContent("\u2699 Configure");
  });
});
