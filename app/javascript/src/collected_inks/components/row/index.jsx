import * as React from "react";
import { connect } from "react-redux";

import {
  deleteEntry,
  togglePrivacy,
  toggleSwabbed,
  toggleUsed,
  updateKind,
} from "src/collected_inks/actions";
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
      <td>{props.comment}</td>
      <td>
        <span className="actions">
          <a className="btn btn-default"><i className="fa fa-archive" /></a>
          <DeleteButton deletable={props.deletable} onClick={props.onDelete}/>
        </span>
      </td>
    </tr>;
  }

  className() {
    return (this.props.private ? "private" : "");
  }
}

const DeleteButton = ({deletable, onClick}) => {
  if (!deletable) return null;
  return <a onClick={onClick} className="btn btn-default"><i className="fa fa-trash" /></a>;
}

const mapDispatchToProps = (dispatch, {id}) => ({
  onChangeKind(value) {
    dispatch(updateKind(id, value))
  },
  onDelete() {
    dispatch(deleteEntry(id))
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
