// Mock all the dependencies
vi.mock("react-dom/client", () => ({
  createRoot: vi.fn()
}));

vi.mock("admin/components/clustering/App", () => ({
  App: vi.fn(() => <div data-testid="app">App</div>)
}));

vi.mock("admin/micro-clusters/assignCluster", () => ({
  assignCluster: vi.fn()
}));

vi.mock("admin/micro-clusters/createMacroClusterAndAssign", () => ({
  createMacroClusterAndAssign: vi.fn()
}));

vi.mock("admin/micro-clusters/extraColumn", () => ({
  extraColumn: vi.fn()
}));

vi.mock("admin/micro-clusters/ignoreCluster", () => ({
  ignoreCluster: vi.fn()
}));

vi.mock("admin/micro-clusters/macroClusters", () => ({
  getMacroClusters: vi.fn(),
  updateMacroCluster: vi.fn()
}));

vi.mock("admin/micro-clusters/microClusters", () => ({
  getMicroClusters: vi.fn()
}));

vi.mock("admin/micro-clusters/withDistance", () => ({
  withDistance: vi.fn()
}));

vi.mock("@honeybadger-io/js", () => ({
  default: { configure: vi.fn(), notify: vi.fn() }
}));

vi.mock("@honeybadger-io/react", () => ({
  HoneybadgerErrorBoundary: ({ children }) => children
}));

describe("micro-clusters index", () => {
  let mockCreateRoot;
  let mockRender;
  let addEventListenerSpy;
  let getElementByIdSpy;

  beforeEach(async () => {
    vi.clearAllMocks();
    vi.resetModules();

    // Spy on document methods BEFORE importing the module
    addEventListenerSpy = vi.spyOn(document, "addEventListener");
    getElementByIdSpy = vi.spyOn(document, "getElementById");

    // Set up mocks
    mockRender = vi.fn();
    mockCreateRoot = vi.fn(() => ({ render: mockRender }));

    const { createRoot } = await import("react-dom/client");
    createRoot.mockImplementation(mockCreateRoot);
  });

  afterEach(() => {
    addEventListenerSpy.mockRestore();
    getElementByIdSpy.mockRestore();
  });

  it("sets up DOMContentLoaded event listener on import", async () => {
    // Import the module
    await import("admin/micro-clusters/index");

    expect(addEventListenerSpy).toHaveBeenCalledWith("DOMContentLoaded", expect.any(Function));
  });

  it("renders App when element exists", async () => {
    const mockElement = document.createElement("div");
    getElementByIdSpy.mockReturnValue(mockElement);

    // Import the module and trigger the event
    await import("admin/micro-clusters/index");
    const eventHandler = addEventListenerSpy.mock.calls[0][1];
    eventHandler();

    expect(getElementByIdSpy).toHaveBeenCalledWith("micro-clusters-app");
    expect(mockCreateRoot).toHaveBeenCalledWith(mockElement);
    expect(mockRender).toHaveBeenCalled();
  });

  it("does not render when element does not exist", async () => {
    getElementByIdSpy.mockReturnValue(null);

    await import("admin/micro-clusters/index");
    const eventHandler = addEventListenerSpy.mock.calls[0][1];
    eventHandler();

    expect(getElementByIdSpy).toHaveBeenCalledWith("micro-clusters-app");
    expect(mockCreateRoot).not.toHaveBeenCalled();
    expect(mockRender).not.toHaveBeenCalled();
  });

  it("passes correct props to App component", async () => {
    const mockElement = document.createElement("div");
    getElementByIdSpy.mockReturnValue(mockElement);

    await import("admin/micro-clusters/index");
    const eventHandler = addEventListenerSpy.mock.calls[0][1];
    eventHandler();

    const appElement = mockRender.mock.calls[0][0].props.children;

    expect(appElement.props).toEqual(
      expect.objectContaining({
        brandSelectorField: "simplified_brand_name",
        fields: ["brand_name", "line_name", "ink_name"]
      })
    );
  });

  it("includes all required function props", async () => {
    const mockElement = document.createElement("div");
    getElementByIdSpy.mockReturnValue(mockElement);

    await import("admin/micro-clusters/index");
    const eventHandler = addEventListenerSpy.mock.calls[0][1];
    eventHandler();

    const appProps = mockRender.mock.calls[0][0].props.children.props;

    expect(appProps).toHaveProperty("microClusterLoader");
    expect(appProps).toHaveProperty("macroClusterLoader");
    expect(appProps).toHaveProperty("macroClusterUpdater");
    expect(appProps).toHaveProperty("assignCluster");
    expect(appProps).toHaveProperty("withDistance");
    expect(appProps).toHaveProperty("ignoreCluster");
    expect(appProps).toHaveProperty("extraColumn");
    expect(appProps).toHaveProperty("createMacroClusterAndAssign");

    // Verify they are functions
    expect(typeof appProps.microClusterLoader).toBe("function");
    expect(typeof appProps.macroClusterLoader).toBe("function");
    expect(typeof appProps.macroClusterUpdater).toBe("function");
    expect(typeof appProps.assignCluster).toBe("function");
    expect(typeof appProps.withDistance).toBe("function");
    expect(typeof appProps.ignoreCluster).toBe("function");
    expect(typeof appProps.extraColumn).toBe("function");
    expect(typeof appProps.createMacroClusterAndAssign).toBe("function");
  });
});
