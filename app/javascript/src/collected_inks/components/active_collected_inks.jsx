import * as React from "react";
import { connect } from "react-redux";

const mapStateToProps = ({ active }) => ({ entries: active });

const ActiveCollectedInks = ({entries}) => <div>{entries.length} active collected inks</div>
export default connect(mapStateToProps)(ActiveCollectedInks);
