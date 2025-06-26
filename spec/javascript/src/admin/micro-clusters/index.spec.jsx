/**
 * @jest-environment jsdom
 */
import React from "react";

// Mock all the dependencies
jest.mock("react-dom/client", () => ({
  createRoot: jest.fn()
}));

jest.mock("admin/components/clustering/App", () => ({
  App: jest.fn(() => <div data-testid="app">App</div>)
}));

jest.mock("admin/micro-clusters/assignCluster", () => ({
  assignCluster: jest.fn()
}));

jest.mock("admin/micro-clusters/createMacroClusterAndAssign", () => ({
  createMacroClusterAndAssign: jest.fn()
}));

jest.mock("admin/micro-clusters/extraColumn", () => ({
  extraColumn: jest.fn()
}));

jest.mock("admin/micro-clusters/ignoreCluster", () => ({
  ignoreCluster: jest.fn()
}));

jest.mock("admin/micro-clusters/macroClusters", () => ({
  getMacroClusters: jest.fn(),
  updateMacroCluster: jest.fn()
}));

jest.mock("admin/micro-clusters/microClusters", () => ({
  getMicroClusters: jest.fn()
}));

jest.mock("admin/micro-clusters/withDistance", () => ({
  withDistance: jest.fn()
}));

describe("micro-clusters index", () => {
  let mockCreateRoot;
  let mockRender;
  let addEventListenerSpy;
  let getElementByIdSpy;

  beforeEach(() => {
    jest.clearAllMocks();
    jest.resetModules();

    // Spy on document methods BEFORE requiring the module
    addEventListenerSpy = jest.spyOn(document, "addEventListener");
    getElementByIdSpy = jest.spyOn(document, "getElementById");

    // Set up mocks
    mockRender = jest.fn();
    mockCreateRoot = jest.fn(() => ({ render: mockRender }));

    const { createRoot } = require("react-dom/client");
    createRoot.mockImplementation(mockCreateRoot);
  });

  afterEach(() => {
    addEventListenerSpy.mockRestore();
    getElementByIdSpy.mockRestore();
  });

  it("sets up DOMContentLoaded event listener on import", () => {
    // Import the module
    require("admin/micro-clusters/index");

    expect(addEventListenerSpy).toHaveBeenCalledWith("DOMContentLoaded", expect.any(Function));
  });

  it("renders App when element exists", () => {
    const mockElement = document.createElement("div");
    getElementByIdSpy.mockReturnValue(mockElement);

    // Import the module and trigger the event
    require("admin/micro-clusters/index");
    const eventHandler = addEventListenerSpy.mock.calls[0][1];
    eventHandler();

    expect(getElementByIdSpy).toHaveBeenCalledWith("micro-clusters-app");
    expect(mockCreateRoot).toHaveBeenCalledWith(mockElement);
    expect(mockRender).toHaveBeenCalled();
  });

  it("does not render when element does not exist", () => {
    getElementByIdSpy.mockReturnValue(null);

    require("admin/micro-clusters/index");
    const eventHandler = addEventListenerSpy.mock.calls[0][1];
    eventHandler();

    expect(getElementByIdSpy).toHaveBeenCalledWith("micro-clusters-app");
    expect(mockCreateRoot).not.toHaveBeenCalled();
    expect(mockRender).not.toHaveBeenCalled();
  });

  it("passes correct props to App component", () => {
    const mockElement = document.createElement("div");
    getElementByIdSpy.mockReturnValue(mockElement);

    require("admin/micro-clusters/index");
    const eventHandler = addEventListenerSpy.mock.calls[0][1];
    eventHandler();

    expect(mockRender).toHaveBeenCalledWith(
      expect.objectContaining({
        props: expect.objectContaining({
          brandSelectorField: "simplified_brand_name",
          fields: ["brand_name", "line_name", "ink_name"]
        })
      })
    );
  });

  it("includes all required function props", () => {
    const mockElement = document.createElement("div");
    getElementByIdSpy.mockReturnValue(mockElement);

    require("admin/micro-clusters/index");
    const eventHandler = addEventListenerSpy.mock.calls[0][1];
    eventHandler();

    const appProps = mockRender.mock.calls[0][0].props;

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
