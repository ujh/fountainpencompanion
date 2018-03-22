import * as React from "react";
import { connect } from "react-redux";

import {
  deleteEntry,
  toggleArchived,
  togglePrivacy,
  toggleSwabbed,
  toggleUsed,
  updateComment,
  updateKind,
} from "src/collected_inks/actions";
import ActionButtons from "./action_buttons";
import Comment from "./comment";
import Kind from "./kind";
import Privacy from "./privacy";
import Swabbed from "./swabbed";
import Used from "./used";

class Row extends React.Component {
  render() {
    const props = this.props;
    return <tr className={this.className()}>
      <td><Privacy private={props.private} onClick={props.onTogglePrivacy} /></td>
      <td>{props.brand_name}</td>
      <td>{props.line_name}</td>
      <td>{props.ink_name}</td>
      <td><Kind kind={props.kind} onChange={props.onChangeKind}/></td>
      <td style={{backgroundColor: props.color}}></td>
      <td><Swabbed swabbed={props.swabbed} onClick={props.onToggleSwabbed}/></td>
      <td><Used used={props.used} onClick={props.onToggleUsed}/></td>
      <td><Comment comment={props.comment} onChange={props.onChangeComment}/></td>
      <td>
        <ActionButtons
          deletable={props.deletable}
          onArchiveClick={props.onToggleArchived}
          onDeleteClick={props.onDeleteClick}
        />
      </td>
    </tr>;
  }

  className() {
    return (this.props.private ? "private" : "");
  }
}

const mapDispatchToProps = (dispatch, {id}) => ({
  onChangeComment(value) {
    dispatch(updateComment(id, value))
  },
  onChangeKind(value) {
    dispatch(updateKind(id, value))
  },
  onDelete() {
    dispatch(deleteEntry(id))
  },
  onToggleArchived() {
    dispatch(toggleArchived(id))
  },
  onTogglePrivacy() {
    dispatch(togglePrivacy(id))
  },
  onToggleSwabbed() {
    dispatch(toggleSwabbed(id))
  },
  onToggleUsed() {
    dispatch(toggleUsed(id))
  },
});

export default connect(null, mapDispatchToProps)(Row);
