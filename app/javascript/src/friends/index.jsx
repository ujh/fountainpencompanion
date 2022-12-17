import * as React from "react";
import { createRoot } from "react-dom/client";
import { deleteRequest, postRequest, putRequest } from "src/fetch";

export const renderFriendButton = (el) => {
  const root = createRoot(el);
  root.render(
    <FriendButton
      id={el.getAttribute("data-id")}
      friendshipState={el.getAttribute("data-state")}
    />
  );
};

class FriendButton extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      friendshipState: props.friendshipState,
    };
  }

  buttonText() {
    switch (this.state.friendshipState) {
      case "friend":
        return "Unfriend";
      case "to-approve":
        return "Approve Friend Request";
      case "waiting-for-approval":
        return "Delete Pending Friend Request";
      case "no-friend":
        return "Send Friend Request";
    }
  }

  onClick() {
    switch (this.state.friendshipState) {
      case "no-friend":
        return this.sendFriendRequest();
      case "to-approve":
        return this.approveFriendRequest();
      case "waiting-for-approval":
        return this.deleteFriendRequest();
      case "friend":
        return this.deleteFriendRequest();
    }
  }

  sendFriendRequest() {
    postRequest(`/friendships?friend_id=${this.props.id}`, {});
    this.setState({ friendshipState: "waiting-for-approval" });
  }

  deleteFriendRequest() {
    deleteRequest(`/friendships/${this.props.id}`, {});
    this.setState({ friendshipState: "no-friend" });
  }

  approveFriendRequest() {
    putRequest(`/friendships/${this.props.id}?approved=true`, {});
    this.setState({ friendshipState: "friend" });
  }

  render() {
    if (this.state.friendshipState == "to-approve") {
      return (
        <div>
          <a
            className="btn btn-danger"
            onClick={() => this.deleteFriendRequest()}
          >
            Delete Friend Request
          </a>
          <a className="btn btn-secondary" onClick={() => this.onClick()}>
            {this.buttonText()}
          </a>
        </div>
      );
    }
    return (
      <div>
        <a className="btn btn-secondary" onClick={() => this.onClick()}>
          {this.buttonText()}
        </a>
      </div>
    );
  }
}
