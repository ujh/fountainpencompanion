import * as React from "react";
import { connect } from "react-redux";

import { deleteEntry } from "src/collected_inks/actions";

class Row extends React.Component {
  render() {
    const props = this.props;
    return <tr className={this.className()}>
      <td><Privacy private={props.private} /></td>
      <td>{props.brand_name}</td>
      <td>{props.line_name}</td>
      <td>{props.ink_name}</td>
      <td>{props.kind}</td>
      <td style={{backgroundColor: props.color}}></td>
      <td className={`swabbed ${props.swabbed}`}><i className={`fa fa-${props.swabbed ? "check" : "times"}`}></i></td>
      <td className={`used ${props.used}`}><i className={`fa fa-${props.used ? "check" : "times"}`}></i></td>
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

const Privacy = (props) => {
  const icon = props.private ? "lock" : "unlock";
  return <i className={`fa fa-${icon}`}></i>;
}
const DeleteButton = ({deletable, onClick}) => {
  if (!deletable) return null;
  return <a onClick={onClick} className="btn btn-default"><i className="fa fa-trash" /></a>;
}

const mapDispatchToProps = (dispatch, {id}) => ({
  onDelete() {
    dispatch(deleteEntry(id))
  }
});

export default connect(null, mapDispatchToProps)(Row);
