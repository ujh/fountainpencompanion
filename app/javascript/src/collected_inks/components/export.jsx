import * as React from "react";
import { connect } from "react-redux";

const Export = ({entries}) => <div className="export">
  <a className="btn btn-default" href="/collected_inks/beta/import">Import data</a>
  <a className="btn btn-primary" href="/collected_inks.csv">Export data</a>
</div>

const mapStateToProps = ({ entries }) => ({ entries });

export default connect(mapStateToProps)(Export);
