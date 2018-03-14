import * as React from "react";
import { connect } from "react-redux";

const Export = ({entries}) => <div className="export">
  <a className="btn btn-primary">Export data</a>
</div>

const mapStateToProps = ({ entries }) => ({ entries });

export default connect(mapStateToProps)(Export);
