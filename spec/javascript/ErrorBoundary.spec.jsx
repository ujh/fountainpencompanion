import { render, screen } from "@testing-library/react";
import { ErrorBoundary } from "ErrorBoundary";
import honeybadger from "honeybadger";

jest.mock("@honeybadger-io/js", () => ({
  __esModule: true,
  default: {
    configure: jest.fn(),
    notify: jest.fn()
  }
}));

jest.mock("@honeybadger-io/react", () => {
  const React = require("react");
  class MockHoneybadgerErrorBoundary extends React.Component {
    constructor(props) {
      super(props);
      this.state = { hasError: false };
    }
    static getDerivedStateFromError() {
      return { hasError: true };
    }
    componentDidCatch(error) {
      this.props.honeybadger.notify(error);
    }
    render() {
      if (this.state.hasError) {
        const ErrorComponent = this.props.ErrorComponent;
        return <ErrorComponent />;
      }
      return this.props.children;
    }
  }
  return { HoneybadgerErrorBoundary: MockHoneybadgerErrorBoundary };
});

const ThrowingComponent = () => {
  throw new Error("Test error");
};

const WorkingComponent = () => <div>Working content</div>;

beforeEach(() => {
  jest.clearAllMocks();
  jest.spyOn(console, "error").mockImplementation(() => {});
});

afterEach(() => {
  console.error.mockRestore();
});

describe("ErrorBoundary", () => {
  it("renders children when no error occurs", () => {
    render(
      <ErrorBoundary>
        <WorkingComponent />
      </ErrorBoundary>
    );

    expect(screen.getByText("Working content")).toBeInTheDocument();
  });

  it("renders fallback UI when a child throws", () => {
    render(
      <ErrorBoundary>
        <ThrowingComponent />
      </ErrorBoundary>
    );

    expect(screen.getByText("Something went wrong")).toBeInTheDocument();
    expect(screen.getByText(/unexpected error/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /reload/i })).toBeInTheDocument();
  });

  it("renders the capybara image in the fallback", () => {
    render(
      <ErrorBoundary>
        <ThrowingComponent />
      </ErrorBoundary>
    );

    const img = document.querySelector("img");
    expect(img).toHaveAttribute("src", "/images/capybara/capybara_square,w_200.png");
  });

  it("reports the error to Honeybadger", () => {
    render(
      <ErrorBoundary>
        <ThrowingComponent />
      </ErrorBoundary>
    );

    expect(honeybadger.notify).toHaveBeenCalledWith(expect.any(Error));
  });
});
