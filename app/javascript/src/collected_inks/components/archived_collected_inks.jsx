import * as React from "react";
import { connect } from "react-redux";

import InkTable from "./ink_table";

const mapStateToProps = ({ archived }) => ({ entries: archived });

const ArchivedCollectedInks = ({entries}) => <div><InkTable entries={entries} /></div>;

export default connect(mapStateToProps)(ArchivedCollectedInks);
