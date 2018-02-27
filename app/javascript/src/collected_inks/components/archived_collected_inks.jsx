import * as React from "react";
import { connect } from "react-redux";

const mapStateToProps = ({ archived }) => ({ entries: archived });

const ArchivedCollectedInks = ({entries}) => <div>{entries.length} archived collected inks</div>
export default connect(mapStateToProps)(ArchivedCollectedInks);
