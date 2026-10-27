import { act, fireEvent, render, renderHook, screen } from "@testing-library/react";
import { DraggableWidget, HiddenWidget, useDragReorder } from "dashboard/dashboard_config";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";

describe("HiddenWidget", () => {
  const server = setupServer(
    http.get("/dashboard/widgets/inks_summary.json", () =>
      HttpResponse.json({
        data: {
          attributes: { count: 1, used: 1, swabbed: 1, archived: 1, inks_without_reviews: 1 }
        }
      })
    )
  );

  beforeAll(() => server.listen());
  afterAll(() => server.close());

  it("renders the widget content and add button", async () => {
    render(<HiddenWidget id="inks_summary" onAdd={vi.fn()} />);
    expect(screen.getByText("Inks")).toBeInTheDocument();
    expect(screen.getByLabelText("Add Inks Summary")).toBeInTheDocument();
    await screen.findByText(/Collection/);
  });

  it("calls onAdd with the widget id when clicked", async () => {
    const onAdd = vi.fn();
    render(<HiddenWidget id="inks_summary" onAdd={onAdd} />);
    await screen.findByText(/Collection/);
    fireEvent.click(screen.getByLabelText("Add Inks Summary"));
    expect(onAdd).toHaveBeenCalledWith("inks_summary");
  });
});

describe("DraggableWidget", () => {
  const defaultProps = {
    id: "inks_summary",
    index: 0,
    isFirst: true,
    isLast: false,
    configuring: true,
    dragging: false,
    onRemove: vi.fn(),
    onMoveUp: vi.fn(),
    onMoveDown: vi.fn(),
    onDragStart: vi.fn(),
    onDragOver: vi.fn(),
    onDrop: vi.fn(),
    onDragEnd: vi.fn()
  };

  it("renders children without configure UI when not configuring", () => {
    render(
      <DraggableWidget {...defaultProps} configuring={false}>
        <div data-testid="child">Content</div>
      </DraggableWidget>
    );
    expect(screen.getByTestId("child")).toBeInTheDocument();
    expect(screen.queryByLabelText("Remove Inks Summary")).not.toBeInTheDocument();
    expect(screen.queryByLabelText("Move Inks Summary up")).not.toBeInTheDocument();
    expect(screen.queryByLabelText("Move Inks Summary down")).not.toBeInTheDocument();
  });

  it("wraps children with remove button when configuring", () => {
    render(
      <DraggableWidget {...defaultProps}>
        <div data-testid="child">Content</div>
      </DraggableWidget>
    );
    expect(screen.getByTestId("child")).toBeInTheDocument();
    expect(screen.getByLabelText("Remove Inks Summary")).toBeInTheDocument();
  });

  it("calls onRemove when remove is clicked", () => {
    const onRemove = vi.fn();
    render(
      <DraggableWidget {...defaultProps} onRemove={onRemove}>
        <div>Content</div>
      </DraggableWidget>
    );
    fireEvent.click(screen.getByLabelText("Remove Inks Summary"));
    expect(onRemove).toHaveBeenCalledWith("inks_summary");
  });

  it("renders move up and move down buttons when configuring", () => {
    render(
      <DraggableWidget {...defaultProps} isFirst={false} isLast={false}>
        <div>Content</div>
      </DraggableWidget>
    );
    expect(screen.getByLabelText("Move Inks Summary up")).toBeEnabled();
    expect(screen.getByLabelText("Move Inks Summary down")).toBeEnabled();
  });

  it("disables both move buttons when only widget", () => {
    render(
      <DraggableWidget {...defaultProps} isFirst={true} isLast={true}>
        <div>Content</div>
      </DraggableWidget>
    );
    expect(screen.getByLabelText("Move Inks Summary up")).toBeDisabled();
    expect(screen.getByLabelText("Move Inks Summary down")).toBeDisabled();
  });

  it("disables move up when first", () => {
    render(
      <DraggableWidget {...defaultProps} isFirst={true} isLast={false}>
        <div>Content</div>
      </DraggableWidget>
    );
    expect(screen.getByLabelText("Move Inks Summary up")).toBeDisabled();
    expect(screen.getByLabelText("Move Inks Summary down")).toBeEnabled();
  });

  it("disables move down when last", () => {
    render(
      <DraggableWidget {...defaultProps} isFirst={false} isLast={true}>
        <div>Content</div>
      </DraggableWidget>
    );
    expect(screen.getByLabelText("Move Inks Summary up")).toBeEnabled();
    expect(screen.getByLabelText("Move Inks Summary down")).toBeDisabled();
  });

  it("calls onMoveUp with index when up is clicked", () => {
    const onMoveUp = vi.fn();
    render(
      <DraggableWidget {...defaultProps} index={1} isFirst={false} onMoveUp={onMoveUp}>
        <div>Content</div>
      </DraggableWidget>
    );
    fireEvent.click(screen.getByLabelText("Move Inks Summary up"));
    expect(onMoveUp).toHaveBeenCalledWith(1);
  });

  it("calls onMoveDown with index when down is clicked", () => {
    const onMoveDown = vi.fn();
    render(
      <DraggableWidget {...defaultProps} index={2} isFirst={false} onMoveDown={onMoveDown}>
        <div>Content</div>
      </DraggableWidget>
    );
    fireEvent.click(screen.getByLabelText("Move Inks Summary down"));
    expect(onMoveDown).toHaveBeenCalledWith(2);
  });
});

describe("useDragReorder", () => {
  it("reorders items live on dragOver with skipServer", () => {
    const ids = ["a", "b", "c"];
    const setIds = vi.fn();
    const saveToServer = vi.fn();
    const { result } = renderHook(() => useDragReorder(ids, setIds, saveToServer));

    act(() => {
      result.current.onDragStart({ dataTransfer: { effectAllowed: null } }, 0);
    });

    act(() => {
      result.current.onDragOver({ preventDefault: vi.fn(), dataTransfer: { dropEffect: null } }, 2);
    });

    expect(setIds).toHaveBeenCalled();
    const [updater, options] = setIds.mock.calls[0];
    expect(updater(ids)).toEqual(["b", "c", "a"]);
    expect(options).toEqual({ skipServer: true });
  });

  it("calls saveToServer on drop", () => {
    const ids = ["a", "b"];
    const setIds = vi.fn();
    const saveToServer = vi.fn();
    const { result } = renderHook(() => useDragReorder(ids, setIds, saveToServer));

    act(() => {
      result.current.onDragStart({ dataTransfer: { effectAllowed: null } }, 0);
    });

    act(() => {
      result.current.onDrop({ preventDefault: vi.fn() });
    });

    expect(saveToServer).toHaveBeenCalled();
    expect(result.current.dragging).toBe(false);
  });

  it("reverts to pre-drag order on dragEnd (cancel)", () => {
    const ids = ["a", "b"];
    const setIds = vi.fn();
    const saveToServer = vi.fn();
    const { result } = renderHook(() => useDragReorder(ids, setIds, saveToServer));

    act(() => {
      result.current.onDragStart({ dataTransfer: { effectAllowed: null } }, 0);
    });

    act(() => {
      result.current.onDragEnd();
    });

    expect(setIds).toHaveBeenCalledWith(ids);
    expect(saveToServer).not.toHaveBeenCalled();
    expect(result.current.dragging).toBe(false);
  });

  it("does nothing on dragOver when hovering same index", () => {
    const ids = ["a", "b"];
    const setIds = vi.fn();
    const saveToServer = vi.fn();
    const { result } = renderHook(() => useDragReorder(ids, setIds, saveToServer));

    act(() => {
      result.current.onDragStart({ dataTransfer: { effectAllowed: null } }, 1);
    });

    act(() => {
      result.current.onDragOver({ preventDefault: vi.fn(), dataTransfer: { dropEffect: null } }, 1);
    });

    expect(setIds).not.toHaveBeenCalled();
  });
});
