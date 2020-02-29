import * as React from "react";
import * as ReactDOM from "react-dom";

export const renderFriendButton = (el) => {
  console.log(el)
  ReactDOM.render(
    <FriendButton id={el.getAttribute('data-id')} state={el.getAttribute('data-state')}/>,
    el
  )
}

class FriendButton extends React.Component {
  buttonText() {
    switch (this.props.state) {
      case "friend":
        return "Unfriend";
      case "to-aprove":
        return "Approve Friend Request";
      case "waiting-for-approval":
        return "Delete Pending Friend Request";
      case "no-friend":
        return "Send Friend Request";
    }
  }

  render() {
    return <div>
      <a className="btn btn-primary">{this.buttonText()}</a>
    </div>;
  }
}
