/**
 * 
 */
package com.novartis.opensource.yada;

import java.util.ArrayList;
import java.util.List;

import net.sf.jsqlparser.expression.BinaryExpression;
import net.sf.jsqlparser.expression.Expression;
import net.sf.jsqlparser.expression.Function;
import net.sf.jsqlparser.expression.JdbcParameter;
import net.sf.jsqlparser.expression.operators.relational.EqualsTo;
import net.sf.jsqlparser.expression.operators.relational.ExpressionList;
import net.sf.jsqlparser.expression.operators.relational.GreaterThan;
import net.sf.jsqlparser.expression.operators.relational.GreaterThanEquals;
import net.sf.jsqlparser.expression.operators.relational.InExpression;
import net.sf.jsqlparser.expression.operators.relational.LikeExpression;
import net.sf.jsqlparser.expression.operators.relational.MinorThan;
import net.sf.jsqlparser.expression.operators.relational.MinorThanEquals;
import net.sf.jsqlparser.expression.operators.relational.NotEqualsTo;
import net.sf.jsqlparser.schema.Column;
import net.sf.jsqlparser.statement.select.SelectVisitor;
import net.sf.jsqlparser.statement.select.SubSelect;

import org.apache.log4j.Logger;

/**
 * A subclass of net.sf.jsqlparser.util.deparser.ExpressionDeParser which is called during
 * com.novartis.opensource.yada.Adaptor processing of UPDATE statement WHERE clauses.
 * @author David Varon 
 */
public class YADAExpressionDeParser extends
		net.sf.jsqlparser.util.deparser.ExpressionDeParser {
	/**
	 * Local logger handle
	 */
	private static Logger l = Logger.getLogger(YADAExpressionDeParser.class);
	/**
	 * A java.util.ArrayList to store instances of {@link Column} found in the WHERE clause
	 */
	private ArrayList<Column>     columns  		    = new ArrayList<>();
	/**
	 * An index of columns referenced by SQL {@code IN} clauses
	 */
	private ArrayList<Column>     inColumns		    = new ArrayList<>();
	/**
	 * An index of columns associated to JDBC parameter symbols
	 */
	private ArrayList<Column>     jdbcColumns       = new ArrayList<>();
	/**
	 * A list of SQL expressions
	 */
	private List<Expression>      expressions       = null;
	/**
	 * A flag for managing query deparsing state
	 */
	public boolean 			          hasExpressionList = false;
	/**
	 * A flag for managing query deparsing state
	 */
	public boolean                hasSubSelect      = false;
	/**
	 * A flag for managing query deparsing state
	 */
	private boolean               inExpression      = false;
	/**
	 * A flag for managing query deparsing state
	 */
	private boolean               inFunction          = false;
	/**
	 * A flag for managing query deparsing state
	 */
	private boolean               hasJdbcParameter  = false;
	/**
	 * A placeholder used when deparsing a binary expression
	 */
	private Column                pendingLeftColumn = null;
	
	/**
	 * A flag for managing query deparsing state, set to {@code true} when traversing an SQL expression. 
	 * @param inExpression set to {@code true} if the deparser is handling an SQL expression.
	 */
	public void setInExpression(boolean inExpression)
	{
		this.inExpression = inExpression;
	}
	
	/**
	 * A flag for managing query deparsing state, set to {@code true} when analyzing an expression that contains
	 * an instance of {@link net.sf.jsqlparser.expression.JdbcParameter}
	 * @param hasJdbcParameter set to {@code true} if the current expression includes a JDBC parameter symbol
	 */
	public void setHasJdbcParameter(boolean hasJdbcParameter)
	{
		this.hasJdbcParameter = hasJdbcParameter;
	}
	
	/**
	 * Returns the jdbc parameter status of the current expression.
	 * @return {@code true} if the current expression has a jdbc parameter
	 */
	public boolean hasJdbcParameter()
	{
		return this.hasJdbcParameter;
	}
	
	
	/**
	 *  Generic constructor, sets SelectDeParser and StringBuffer
	 */
	public YADAExpressionDeParser() 
	{
		this.setBuffer(new StringBuffer());
		YADASelectDeParser selectVistitor = new YADASelectDeParser(this,this.getBuffer());
		this.setSelectVisitor(selectVistitor);
	}

	/**
	 * Inherited constructor, calls <code>super(SelectVisitor selectVisitor, StringBuffer buffer)</code>;
	 * @param selectVisitor the object for processing {@code SELECT} statements
	 * @param buffer the object in which to store deparsing metadata
	 */
	public YADAExpressionDeParser(SelectVisitor selectVisitor, StringBuffer buffer) 
	{
		super(selectVisitor, buffer);
	}
	
	/**
	 * The key method of the visitor pattern.  When called in the deparsing process, adds each
	 * column it finds to the <code>columns</code> array list.
	 * 
	 * @param column the column encountered by the current handler
	 */
	@Override
	public void visit(Column column)
	{
		super.visit(column);
		if(this.inExpression)
			this.pendingLeftColumn = column;
		this.columns.add(column);
	}
	
	/**
	 * Sets {@link #hasJdbcParameter} flag to {@code true}
	 */
	@Override
	public void visit(JdbcParameter jdbcParameter) {
		super.visit(jdbcParameter);
		this.hasJdbcParameter = true;
  }
	
	/**
	 * @return List&lt;Expression&gt; of expressions deparsed from the statement
	 */
	public List<Expression> getExpressions()
	{
		return this.expressions;
	}
	
	/**
	 * Sets {@link #hasExpressionList} parameter to {@code true}, and indexes 
	 * expressions.
	 */
	@SuppressWarnings("unchecked")
  @Override
	public void visit(ExpressionList expressionList)
	{
		super.visit(expressionList);
		l.debug("processing expression list");
		this.hasExpressionList = true;
		this.expressions = expressionList.getExpressions();
	}
	
	/**
	 * Sets {@link #hasSubSelect} flag to {@code true}.
	 */
	@Override
	public void visit(SubSelect subSelect)
	{
		super.visit(subSelect);
		this.hasSubSelect = true;
	}
	
	/**
	 * Sets {@link #inExpression} flag to {@code true} and calls handler.
	 */
	@Override
	public void visit(InExpression in)
	{
		this.inExpression = true;
		super.visit(in);
		handleInExpression(in);
	}
	
	/**
	 * Sets {@link #inFunction} flag to {@code true} and calls handler.
	 */
	@Override
	public void visit(Function f)
	{
		//inExpression = true;
		this.inFunction = true;
		super.visit(f);
		handleFunction(f);
	}
	
	/**
	 * Handler for extracting column names from functions if they map to JDBC parameters.
	 * @param f the current SQL function to evaluate
	 */
	public void handleFunction(Function f)
	{
		if(this.inFunction && this.hasJdbcParameter)
		{
			l.debug("Function contains jdbc parameter");	
		}
		else if(this.inExpression && this.hasJdbcParameter)
		{
			l.debug("Function contains jdbc parameter");
			this.jdbcColumns.add(this.pendingLeftColumn);
		}
	}
	
	/**
	 * Handler for extracting the column on the left side of an SQL {@code in} clause
	 * @param in the SQL {@code in} clause to evaluate
	 */
	public void handleInExpression(InExpression in)
	{
		if (this.inExpression && this.hasJdbcParameter)
		{
			this.jdbcColumns.add(this.pendingLeftColumn);
			this.inColumns.add(this.pendingLeftColumn);
		}
		this.inExpression = false;
		this.hasJdbcParameter = false;
		this.pendingLeftColumn = null;
	}
	
	/**
	 * 
	 */
	@Override
	public void visit(EqualsTo expr)
	{
		this.inExpression = true;
		super.visit(expr);
		handleBinaryExpression(expr);
	}
	
	/**
	 * 
	 */
	@Override
	public void visit(NotEqualsTo expr)
	{
		this.inExpression = true;
		super.visit(expr);
		handleBinaryExpression(expr);
	}
	
	/**
	 * 
	 */
	@Override
	public void visit(MinorThan expr)
	{
		this.inExpression = true;
		super.visit(expr);
		handleBinaryExpression(expr);
	}
	
	/**
	 * 
	 */
	@Override
	public void visit(MinorThanEquals expr)
	{
		this.inExpression = true;
		super.visit(expr);
		handleBinaryExpression(expr);
	}
	
	/**
	 * 
	 */
	@Override
	public void visit(GreaterThan expr)
	{
		this.inExpression = true;
		super.visit(expr);
		handleBinaryExpression(expr);
	}
	
	/**
	 * 
	 */
	@Override
	public void visit(GreaterThanEquals expr)
	{
		this.inExpression = true;
		super.visit(expr);
		handleBinaryExpression(expr);
	}
	
	/**
	 * 
	 */
	@Override
	public void visit(LikeExpression expr)
	{
		this.inExpression = true;
		super.visit(expr);	
		handleBinaryExpression(expr);
	}
	
	/**
	 * Handler to extract column names where appropriate (inside an expression which contains a jdbc parameter) and to set deparser flags.
	 * @param be the binary expression currently under evaluation
	 */
	public void handleBinaryExpression(BinaryExpression be)
	{
		if (this.inExpression && this.hasJdbcParameter)
		{
			this.jdbcColumns.add(this.pendingLeftColumn);
		}
		this.inExpression = false;
		this.hasJdbcParameter = false;
		this.pendingLeftColumn = null;
	}
	
	/**
	 * 
	 * @return java.util.ArrayList the <code>columns</code> java.util.ArrayList 
	 */
	public ArrayList<Column> getColumns()
	{
		return this.columns;
	}
	
	/**
	 * 
	 * @return java.util.ArrayList the <code>ins</code> java.util.ArrayList 
	 */
	public ArrayList<Column> getInColumns()
	{
		return this.inColumns;
	}
	
	/**
	 * @return java.util.ArrayList the <code>jdbcColumns</code> java.util.ArrayList 
	 */
	public ArrayList<Column> getJdbcColumns()
	{
		return this.jdbcColumns;
	}

}
